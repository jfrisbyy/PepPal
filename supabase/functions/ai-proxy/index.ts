// Supabase Edge Function: ai-proxy
// Authenticated proxy in front of OpenRouter so we never ship the
// OpenRouter API key to the client. Clients send their Supabase JWT;
// we validate it, then forward the chat-completion body to OpenRouter
// using the server-only OPENROUTER_API_KEY.
//
// Hardening + cost controls:
// - Per-user 30 req/min rate limit (rolling 1-minute window).
// - Per-user daily token budget (default 3_000_000 tokens/day, overridable
//   per user via ai_usage_daily.daily_token_limit). Hard 429 over limit.
// - Model allow-list to prevent calling exotic / expensive models.
// - 8 MB request body cap (vision payloads).
// - Anthropic prompt caching: when an anthropic/* model is called and the
//   system prompt is >1k tokens (~4k chars), we transform the system
//   message into the array form with cache_control: ephemeral so
//   OpenRouter forwards it as a cached prefix. ~90% cost off cache hits.
// - Optional response cache: callers may pass \`cache_key\` (+ optional
//   \`cache_ttl_seconds\`, default 24h). If we have a non-expired row in
//   ai_response_cache for that key, we return it without billing the
//   upstream. On cache miss we forward, then store the response body.
// - Per-call attribution: after every authenticated OpenRouter attempt
//   (cache hit, upstream success, or upstream non-2xx) we write one row
//   to ai_call_log via the service-role client. Best-effort: wrapped in
//   try/catch so a telemetry failure never blocks the user request.
// - Logging hygiene: NEVER log prompts/responses/tokens. On upstream
//   failure we log only { status, model, userIdHash, errorBodySnippet }.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {   extractPromptId,   logAiCall,   resolveModel,   resolveCacheTtl,   DEDUPE_ENABLED,   resolveDedupeTtl,   hashInputs,   lookupInsightsCache,   writeInsightsCache, } from "./_call_log.ts";
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MAX_REQUEST_BYTES = 8 * 1024 * 1024; // 8 MB (vision payloads)
const RATE_LIMIT_PER_MIN = 30;
const DEFAULT_DAILY_TOKEN_LIMIT = 3_000_000;

// Anthropic prompt-caching threshold. Anthropic charges a 25% premium on the
// initial cache write but reads cost ~10% of normal input tokens, so caching
// pays off the second time a prompt is reused. Apply only to system prompts
// large enough to actually save money — small prompts add overhead with no
// upside. ~4000 chars ≈ 1k tokens.
const CACHE_PROMPT_CHAR_THRESHOLD = 4_000;
const DEFAULT_RESPONSE_CACHE_TTL = 24 * 60 * 60; // 24h
const MAX_RESPONSE_CACHE_TTL = 7 * 24 * 60 * 60; // hard cap 7d
const MAX_CACHE_KEY_LEN = 512;

// Allow-list of models that may be requested through the proxy. Keeps
// callers from billing exotic / expensive models against our key.
const ALLOWED_MODELS = new Set<string>([
  "anthropic/claude-haiku-4.5",
  "anthropic/claude-sonnet-4.6",
  "openai/gpt-4o",
  "openai/gpt-4o-2024-11-20",
  "google/gemini-3-flash",
  "perplexity/sonar",
]);

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

// Hash a user id for log lines so we never write the raw uuid.
async function hashUserId(userId: string): Promise<string> {
  const data = new TextEncoder().encode(userId);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .slice(0, 6)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Stable hash for cache keys — we don't want to store potentially-PII
// cache keys verbatim.
async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// In-memory per-user counter — fine for a single instance; replace with
// Redis if you scale to multiple isolates later.
const counters = new Map<string, { resetAt: number; count: number }>();
function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const entry = counters.get(userId);
  if (!entry || entry.resetAt < now) {
    counters.set(userId, { resetAt: now + 60_000, count: 1 });
    return true;
  }
  if (entry.count >= RATE_LIMIT_PER_MIN) return false;
  entry.count += 1;
  return true;
}

function midnightUTCInSeconds(): number {
  const now = new Date();
  const tomorrow = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + 1,
    0, 0, 0, 0,
  );
  return Math.floor((tomorrow - now.getTime()) / 1000);
}

// Apply Anthropic prompt caching to the system message in-place. Only runs
// when the model is anthropic/* and the system prompt is large enough that
// the cache write premium is worth paying.
function applyAnthropicPromptCache(body: Record<string, unknown>): void {
  const model = typeof body.model === "string" ? body.model : "";
  if (!model.startsWith("anthropic/")) return;
  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) return;

  for (const msg of messages) {
    if (!msg || typeof msg !== "object") continue;
    const m = msg as Record<string, unknown>;
    if (m.role !== "system") continue;
    const content = m.content;
    if (typeof content === "string") {
      if (content.length < CACHE_PROMPT_CHAR_THRESHOLD) return;
      m.content = [
        {
          type: "text",
          text: content,
          cache_control: { type: "ephemeral" },
        },
      ];
      return;
    }
    if (Array.isArray(content) && content.length > 0) {
      // Tag the last text block in the system array (Anthropic best practice).
      const totalChars = content.reduce((acc, b) => {
        const t = (b && typeof b === "object" && (b as Record<string, unknown>).text);
        return acc + (typeof t === "string" ? t.length : 0);
      }, 0);
      if (totalChars < CACHE_PROMPT_CHAR_THRESHOLD) return;
      for (let i = content.length - 1; i >= 0; i--) {
        const b = content[i];
        if (b && typeof b === "object" && (b as Record<string, unknown>).type === "text") {
          (b as Record<string, unknown>).cache_control = { type: "ephemeral" };
          return;
        }
      }
    }
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const openRouterKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!supabaseUrl || !serviceRoleKey || !anonKey || !openRouterKey) {
    return json(500, { error: "server_misconfigured" });
  }

  // ---- Auth -----------------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (!jwt) {
    console.error(JSON.stringify({
      event: "ai_proxy_auth_missing_bearer",
      hasHeader: authHeader.length > 0,
    }));
    return json(401, { error: "unauthorized", reason: "missing_bearer" });
  }

  // Validate the JWT by calling GoTrue's /auth/v1/user directly. This
  // works with BOTH legacy HS256 secrets and the new asymmetric
  // (RS256/ES256) signing keys, because GoTrue itself does the
  // verification — we don't try to verify the signature locally.
  let userId: string;
  try {
    const userResp = await fetch(`${supabaseUrl}/auth/v1/user`, {
      method: "GET",
      headers: {
        "apikey": anonKey,
        "Authorization": `Bearer ${jwt}`,
      },
    });
    if (!userResp.ok) {
      const snippet = (await userResp.text()).slice(0, 256);
      console.error(JSON.stringify({
        event: "ai_proxy_auth_rejected",
        status: userResp.status,
        error: snippet,
      }));
      return json(401, {
        error: "unauthorized",
        reason: "jwt_rejected",
        upstream_status: userResp.status,
      });
    }
    const userJson = await userResp.json() as { id?: string };
    if (!userJson?.id) {
      return json(401, { error: "unauthorized", reason: "no_user_id" });
    }
    userId = userJson.id;
  } catch (err) {
    console.error(JSON.stringify({
      event: "ai_proxy_auth_fetch_failed",
      error: String(err).slice(0, 256),
    }));
    return json(401, { error: "unauthorized", reason: "auth_fetch_failed" });
  }

  // Telemetry attribution: capture wall-clock start and the caller's
  // prompt id from the X-Epti-Prompt-Id header. extractPromptId falls
  // back to "unknown" if the header is missing or malformed.
  const startedAt = Date.now();
  const promptId = extractPromptId(req);

  // Service-role client is still used for token-budget RPCs below.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (!checkRateLimit(userId)) {
    return json(429, { error: "rate_limited" });
  }

  // ---- Daily token budget --------------------------------------
  // Hard cap: if the user has already burned through their daily
  // budget we return 429 BEFORE forwarding to upstream. This is the
  // safety net that prevents a runaway bug or abusive caller from
  // racking up unbounded OpenRouter spend.
  try {
    const { data: usageRow } = await admin
      .rpc("ai_usage_today", { p_user_id: userId });
    const row = Array.isArray(usageRow) ? usageRow[0] : usageRow;
    const usedToday = Number(row?.total_tokens ?? 0);
    const limit = Number(row?.daily_token_limit ?? DEFAULT_DAILY_TOKEN_LIMIT);
    const effectiveLimit = Number.isFinite(limit) && limit > 0
      ? limit
      : DEFAULT_DAILY_TOKEN_LIMIT;
    if (usedToday >= effectiveLimit) {
      return json(429, {
        error: "daily_budget_exceeded",
        used: usedToday,
        limit: effectiveLimit,
        retry_after_seconds: midnightUTCInSeconds(),
      });
    }
  } catch (_) {
    // Soft-fail: if the budget check itself errors, allow the request
    // through rather than locking everyone out. We still log nothing.
  }

  // ---- Body -----------------------------------------------------
  const lengthHeader = req.headers.get("content-length");
  if (lengthHeader && Number(lengthHeader) > MAX_REQUEST_BYTES) {
    return json(413, { error: "payload_too_large" });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json(400, { error: "invalid_json" });
  }

  const model = typeof body.model === "string" ? body.model : "";

  // PR 1: Server-side model routing. Caller-supplied body.model is a
  // fallback; routing map keyed by prompt_id has final say so we keep
  // judgment-heavy surfaces on Sonnet and bulk surfaces on Haiku.
  const routedModel = resolveModel(promptId, model);
  body.model = routedModel;
  if (!routedModel || !ALLOWED_MODELS.has(routedModel)) {
    return json(400, { error: "model_not_allowed", model: routedModel });
  }
  if (!Array.isArray(body.messages)) {
    return json(400, { error: "missing_messages" });
  }

  // ---- Response cache (opt-in via cache_key) -------------------
  // Strip cache directives BEFORE forwarding — OpenRouter would 400.
  const rawCacheKey = typeof body.cache_key === "string" ? body.cache_key : "";
  const rawTTL = Number(body.cache_ttl_seconds);
  // PR 1: Allow per-surface server-side TTL overrides when caller did
  // not supply one. Caller-supplied TTL still wins (and is clamped).
  const overrideTTL = resolveCacheTtl(promptId, Number.isFinite(rawTTL) && rawTTL > 0 ? rawTTL : undefined);
  const cacheTTL = overrideTTL !== undefined
    ? Math.min(Math.floor(overrideTTL), MAX_RESPONSE_CACHE_TTL)
    : DEFAULT_RESPONSE_CACHE_TTL;
  delete body.cache_key;
  delete body.cache_ttl_seconds;

  let cacheKeyHash: string | null = null;
  if (rawCacheKey && rawCacheKey.length <= MAX_CACHE_KEY_LEN) {
    // Namespace by model so an anthropic vs. openai answer don't collide.
    cacheKeyHash = await sha256Hex(`${model}::${rawCacheKey}`);
    try {
      const { data: cached } = await admin
        .from("ai_response_cache")
        .select("response_body, content_type")
        .eq("key_hash", cacheKeyHash)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();
      if (cached?.response_body) {
        // Telemetry: log the cache hit before short-circuiting. Best-effort;
        // a telemetry failure must never block a cache-hit response.
        try {
          await logAiCall(admin, {
            userId,
            promptId,
            model: routedModel,
            status: 200,
            cacheHit: true,
            promptTokens: 0,
            completionTokens: 0,
            latencyMs: Date.now() - startedAt,
          });
        } catch (_) {
          // swallow
        }
        return new Response(cached.response_body as string, {
          status: 200,
          headers: {
            ...CORS_HEADERS,
            "Content-Type": (cached.content_type as string) ?? "application/json",
            "X-AIProxy-Cache": "HIT",
          },
        });
      }
    } catch (_) {
      // Cache lookup failures must never block the request.
    }
  }

  // ---- PR 3: Persistent insights cache (per (user, prompt_id, inputs)) 
  // ----------------------------------------------------------------
  // For surfaces in DEDUPE_ENABLED we hash the routed-model + canonical
  // body and short-circuit on a non-expired hit. Caller-driven cache_key
  // path above still wins when it produces a hit, so this is purely
  // additive. A lookup failure never blocks the request.
  let dedupeInputsHash: string | null = null;
  if (DEDUPE_ENABLED.has(promptId)) {
    try {
      dedupeInputsHash = await hashInputs(promptId, routedModel, body);
      const hit = await lookupInsightsCache(admin, {
        userId,
        promptId,
        inputsHash: dedupeInputsHash,
      });
      if (hit) {
        try {
          await logAiCall(admin, {
            userId,
            promptId,
            model: hit.model,
            status: 200,
            cacheHit: true,
            promptTokens: 0,
            completionTokens: 0,
            latencyMs: Date.now() - startedAt,
          });
        } catch (_) {
          // swallow
        }
        return new Response(hit.responseBody, {
          status: 200,
          headers: {
            ...CORS_HEADERS,
            "Content-Type": "application/json",
            "X-AIProxy-Cache": "HIT",
            "X-AIProxy-Insights-Cache": "HIT",
          },
        });
      }
    } catch (_) {
      // Dedupe lookup must never block the request; fall through.
    }
  }

  // ---- Anthropic prompt caching --------------------------------
  applyAnthropicPromptCache(body);

  // ---- Forward --------------------------------------------------
  const userHash = await hashUserId(userId);
  try {
    const upstream = await fetch(OPENROUTER_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openRouterKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "com.peppal.app",
        "X-Title": "EPTI",
      },
      body: JSON.stringify(body),
    });
    const text = await upstream.text();
    const upstreamContentType = upstream.headers.get("content-type") ?? "application/json";

    // Best-effort token accounting. Only parse on success; never log
    // the response body itself.
    if (upstream.ok) {
      let promptTokens = 0;
      let completionTokens = 0;
      try {
        const parsed = JSON.parse(text) as {
          usage?: {
            prompt_tokens?: number;
            completion_tokens?: number;
          };
        };
        promptTokens = Math.max(0, Math.floor(Number(parsed?.usage?.prompt_tokens ?? 0)));
        completionTokens = Math.max(0, Math.floor(Number(parsed?.usage?.completion_tokens ?? 0)));
        if (promptTokens > 0 || completionTokens > 0) {
          await admin.rpc("ai_usage_increment", {
            p_user_id: userId,
            p_prompt_tokens: promptTokens,
            p_completion_tokens: completionTokens,
          });
        }
      } catch (_) {
        // Token usage is non-critical; don't fail the request.
      }

      // PR 3: persist successful insights-cache row when applicable.
      // Best-effort: a write failure must never affect the response we
      // already give the caller. Skipped if we did not compute a hash
      // for this request (i.e. surface not in DEDUPE_ENABLED).
      if (dedupeInputsHash) {
        try {
          await writeInsightsCache(admin, {
            userId,
            promptId,
            inputsHash: dedupeInputsHash,
            model: routedModel,
            responseBody: text,
            promptTokens,
            completionTokens,
            ttlSeconds: resolveDedupeTtl(promptId),
          });
        } catch (_) {
          // swallow
        }
      }

      // Persist successful response to cache (best-effort).
      if (cacheKeyHash) {
        try {
          const expiresAt = new Date(Date.now() + cacheTTL * 1000).toISOString();
          await admin
            .from("ai_response_cache")
            .upsert({
              key_hash: cacheKeyHash,
              model: routedModel,
              response_body: text,
              content_type: upstreamContentType,
              expires_at: expiresAt,
            }, { onConflict: "key_hash" });
        } catch (_) {
          // Cache write failure is non-critical.
        }
      }

      // Telemetry: log the successful upstream call. Best-effort;
      // a telemetry failure must never block a successful response.
      try {
        await logAiCall(admin, {
          userId,
          promptId,
          model: routedModel,
          status: upstream.status,
          cacheHit: false,
          promptTokens,
          completionTokens,
          latencyMs: Date.now() - startedAt,
        });
      } catch (_) {
        // swallow
      }
    } else {
      // Log only the metadata + a trimmed snippet of the upstream
      // error body (NOT the request body, NOT the response body of
      // a successful call). 512-char cap to keep noise out of logs.
      const snippet = text.length > 512 ? text.slice(0, 512) + "…" : text;
      console.error(JSON.stringify({
        event: "ai_proxy_upstream_error",
        status: upstream.status,
        model: routedModel,
        user: userHash,
        error: snippet,
      }));
      // Telemetry: log the upstream non-2xx. Best-effort; a telemetry
      // failure must never escalate an already-errored request.
      try {
        await logAiCall(admin, {
          userId,
          promptId,
          model: routedModel,
          status: upstream.status,
          cacheHit: false,
          promptTokens: 0,
          completionTokens: 0,
          latencyMs: Date.now() - startedAt,
          errorCode: `upstream_${upstream.status}`,
        });
      } catch (_) {
        // swallow
      }
    }

    return new Response(text, {
      status: upstream.status,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": upstreamContentType,
        "X-AIProxy-Cache": cacheKeyHash ? "MISS" : "BYPASS",
      },
    });
  } catch (err) {
    console.error(JSON.stringify({
      event: "ai_proxy_fetch_failed",
      model: routedModel,
      user: userHash,
      error: String(err).slice(0, 256),
    }));
    return json(502, { error: "upstream_error" });
  }
});
