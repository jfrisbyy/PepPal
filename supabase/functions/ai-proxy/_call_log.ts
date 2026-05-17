// Per-call attribution telemetry helper for the ai-proxy edge function.
// Writes one row to public.ai_call_log per attempted OpenRouter call (or
// cache hit). Never logs prompts, responses, or completion text — only
// structured metadata used for cost attribution and model-routing analysis.
//
// All public functions are best-effort: callers MUST wrap invocations in
// try/catch so a telemetry failure never blocks a user-facing request.

// OpenRouter pricing (USD per 1M tokens), captured 2026-06-05. These are
// the only models the proxy allow-list permits; a missing entry means the
// allow-list was widened without updating this map — we fall back to zero
// cost and rely on token counts for ranking until pricing is added.
//
// Source: https://openrouter.ai/models — verify before each release.
const MODEL_PRICING: Record<string, { input: number; output: number }> = {
  "anthropic/claude-haiku-4.5": { input: 1.00, output: 5.00 },
  "anthropic/claude-sonnet-4.6": { input: 3.00, output: 15.00 },
  "openai/gpt-4o": { input: 2.50, output: 10.00 },
  "openai/gpt-4o-2024-11-20": { input: 2.50, output: 10.00 },
  "google/gemini-3-flash": { input: 0.30, output: 2.50 },
  "perplexity/sonar": { input: 1.00, output: 1.00 },
};

const PROMPT_ID_PATTERN = /^[a-z0-9_]{1,64}$/;

export function extractPromptId(req: Request): string {
  const raw = req.headers.get("X-Epti-Prompt-Id") ?? "";
  return PROMPT_ID_PATTERN.test(raw) ? raw : "unknown";
}

export function computeCostUsd(
  model: string,
  promptTokens: number,
  completionTokens: number,
): number {
  const pricing = MODEL_PRICING[model];
  if (!pricing) return 0;
  const inputCost = (promptTokens / 1_000_000) * pricing.input;
  const outputCost = (completionTokens / 1_000_000) * pricing.output;
  // numeric(10, 6) — round to 6 dp to match column precision
  return Math.round((inputCost + outputCost) * 1_000_000) / 1_000_000;
}

export interface AiCallLogParams {
  userId: string;
  promptId: string;
  model: string;
  status: number;
  cacheHit: boolean;
  promptTokens: number;
  completionTokens: number;
  latencyMs: number;
  errorCode?: string | null;
  // PR 3 (Tier 2): registry version of the system prompt actually used
  // for this call. Null when the prompt was not served from the registry
  // (either prompt_id not in REGISTRY_AUTHORITATIVE_PROMPTS, or the
  // registry lookup failed / was a no-op). Lets us partition cost and
  // latency by prompt version once we start iterating server-side.
  promptVersion?: number | null;
}

// `admin` is a service-role Supabase client. We accept it via a structural
// type rather than re-importing supabase-js to avoid a duplicate module
// instance (Deno's loader interns by URL, but being explicit is cheaper).
export interface AdminLike {
  from(table: string): {
    insert(row: Record<string, unknown>): Promise<{ error: unknown }>;
  };
}

export async function logAiCall(
  admin: AdminLike,
  params: AiCallLogParams,
): Promise<void> {
  const costUsd = computeCostUsd(
    params.model,
    params.promptTokens,
    params.completionTokens,
  );
  await admin.from("ai_call_log").insert({
    user_id: params.userId,
    prompt_id: params.promptId,
    model: params.model,
    status: params.status,
    cache_hit: params.cacheHit,
    prompt_tokens: params.promptTokens,
    completion_tokens: params.completionTokens,
    cost_usd: costUsd,
    latency_ms: params.latencyMs,
    error_code: params.errorCode ?? null,
    prompt_version: params.promptVersion ?? null,
  });
}

// =====================================================================
// PR 1: Model routing + server-side cache TTL overrides
// =====================================================================
// Surface-to-model routing keyed by prompt_id (from X-Epti-Prompt-Id).
// Sonnet for high-judgment / user-facing reasoning; Haiku for bulk and
// deterministic structured tasks. Caller-supplied body.model is treated
// as a fallback only - server has final say on routing per surface.
export const MODEL_ROUTING: Record<string, string> = {
  // High-judgment surfaces -> Sonnet 4.6
  bloodwork_interp:    "anthropic/claude-sonnet-4.6",
  ai_program:          "anthropic/claude-sonnet-4.6",
  peptide_chat:        "anthropic/claude-sonnet-4.6",
  journey_narrative:   "anthropic/claude-sonnet-4.6",
  story_mode:          "anthropic/claude-sonnet-4.6",
  finn_chat:           "anthropic/claude-sonnet-4.6",
  // Bulk / structured / cacheable -> Haiku 4.5
  daily_brief:         "anthropic/claude-haiku-4.5",
  insights_agent:      "anthropic/claude-haiku-4.5",
  vial_label_scan:     "anthropic/claude-haiku-4.5",
  vial_integrity:      "anthropic/claude-haiku-4.5",
  lab_parse:           "anthropic/claude-haiku-4.5",
  nutrition_ai:        "anthropic/claude-haiku-4.5",
  add_vial_flow:       "anthropic/claude-haiku-4.5",
  global_search_extras:"anthropic/claude-haiku-4.5",
};

// Server-side response_cache TTL overrides per prompt_id, in seconds.
// Only applied when caller does not pass cache_ttl_seconds in the body.
// Surfaces not listed here get the global DEFAULT_RESPONSE_CACHE_TTL.
export const CACHE_TTL_OVERRIDES: Record<string, number> = {
  daily_brief:      1800,     // 30 min
  vial_integrity:   604800,   // 7 days
  vial_label_scan:  2592000,  // 30 days
  lab_parse:        2592000,  // 30 days
  nutrition_ai:     86400,    // 24h
  insights_agent:   3600,     // 1h
  // chat / program / narrative surfaces intentionally absent -> no server cache
};

// Resolve the model that should actually be used for this call.
// Routing map wins; caller-supplied model is fallback only.
export function resolveModel(promptId: string, requestedModel: string): string {
  return MODEL_ROUTING[promptId] || requestedModel;
}

// Resolve the response-cache TTL (seconds). Caller wins if they passed one.
// Returns undefined when neither caller nor override applies, so the caller
// can fall back to the global default.
export function resolveCacheTtl(promptId: string, callerTtl: number | undefined): number | undefined {
  if (typeof callerTtl === "number" && callerTtl > 0) return callerTtl;
  return CACHE_TTL_OVERRIDES[promptId];
}
// ============================================================
// PR 3: Persistent insights cache (per (user, prompt_id, inputs_hash))
//
// Unlike CACHE_TTL_OVERRIDES + ai_response_cache, which require the
// caller to opt-in by sending a cache_key header, this layer is
// prompt_id-driven and zero-config for the client. The ai-proxy
// hashes the post-routing request body itself and short-circuits
// repeat invocations whose inputs have not changed. Target: Sonnet
// 4.6 spend on insights_agent invocations (~76% of total AI cost).
// ============================================================

// Which prompt_ids participate. Add cautiously: deterministic,
// inputs-fully-captured-in-body surfaces only. Chat / narrative /
// any prompt that mixes in server-side timestamps must stay out.
export const DEDUPE_ENABLED: Set<string> = new Set([
  "insights_agent",
]);

// Per-surface TTL (seconds) for the persistent insights cache.
// Falls back to DEDUPE_DEFAULT_TTL when a surface is in DEDUPE_ENABLED
// but absent from this map. We default the insights agent to 1h so a
// user logging a new meal sees a fresh investigation within the hour.
export const DEDUPE_DEFAULT_TTL = 3600; // 1h
export const DEDUPE_TTL_OVERRIDES: Record<string, number> = {
  insights_agent: 3600, // 1h
};

export function resolveDedupeTtl(promptId: string): number {
  return DEDUPE_TTL_OVERRIDES[promptId] ?? DEDUPE_DEFAULT_TTL;
}

// Canonicalize a request body for stable hashing. Sorts object keys
// at every level so { a: 1, b: 2 } and { b: 2, a: 1 } hash equal.
// Arrays preserve order (message order matters). Drops a few known
// non-deterministic fields the caller might include (e.g. `stream`,
// `cache_key`, `cache_ttl_seconds`) — those are transport-level
// hints, not part of the semantic input.
const NON_SEMANTIC_KEYS = new Set([
  "stream",
  "cache_key",
  "cache_ttl_seconds",
  "user", // OpenAI-style user id passthrough
  "metadata",
]);

export function canonicalizeBody(body: unknown): string {
  const seen = new WeakSet<object>();
  const walk = (v: unknown): unknown => {
    if (v === null || typeof v !== "object") return v;
    if (seen.has(v as object)) return null;
    seen.add(v as object);
    if (Array.isArray(v)) return v.map(walk);
    const obj = v as Record<string, unknown>;
    const keys = Object.keys(obj).filter((k) => !NON_SEMANTIC_KEYS.has(k)).sort();
    const out: Record<string, unknown> = {};
    for (const k of keys) out[k] = walk(obj[k]);
    return out;
  };
  return JSON.stringify(walk(body));
}

// SHA-256 of a string -> lowercase hex. Used to fingerprint the
// canonicalized request body. Web Crypto is available in Deno.
export async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const bytes = new Uint8Array(digest);
  let out = "";
  for (const b of bytes) out += b.toString(16).padStart(2, "0");
  return out;
}

// Compose the full inputs hash for an insights-cache lookup. The hash
// includes the *routed* model so a routing change automatically busts
// the cache for that surface.
export async function hashInputs(
  promptId: string,
  routedModel: string,
  body: unknown,
): Promise<string> {
  const canonical = canonicalizeBody(body);
  return await sha256Hex(promptId + "|" + routedModel + "|" + canonical);
}

// Look up a non-expired cached response. Returns the raw response body
// string (already-JSON) the proxy can stream back verbatim, plus the
// model that produced it (for accurate cache-hit telemetry). Returns
// null on miss / error — a lookup failure must never block the request.
// deno-lint-ignore no-explicit-any
export async function lookupInsightsCache(admin: any, params: {
  userId: string;
  promptId: string;
  inputsHash: string;
}): Promise<{ responseBody: string; model: string } | null> {
  try {
    const { data } = await admin
      .from("ai_insights_cache")
      .select("response_body, model")
      .eq("user_id", params.userId)
      .eq("prompt_id", params.promptId)
      .eq("inputs_hash", params.inputsHash)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (!data) return null;
    const body = data.response_body;
    const responseBody = typeof body === "string" ? body : JSON.stringify(body);
    return { responseBody, model: data.model };
  } catch (_) {
    return null;
  }
}

// Upsert a successful response into the cache. Best-effort: a write
// failure must never affect the response the caller already gets.
// deno-lint-ignore no-explicit-any
export async function writeInsightsCache(admin: any, params: {
  userId: string;
  promptId: string;
  inputsHash: string;
  model: string;
  responseBody: string;
  promptTokens: number;
  completionTokens: number;
  ttlSeconds: number;
}): Promise<void> {
  try {
    const expiresAt = new Date(Date.now() + params.ttlSeconds * 1000).toISOString();
    // Try to store the body as parsed jsonb. If it is not valid JSON we
    // fall back to a string-typed jsonb value, which the lookup path
    // also handles.
    let parsed: unknown;
    try { parsed = JSON.parse(params.responseBody); }
    catch (_) { parsed = params.responseBody; }
    await admin
      .from("ai_insights_cache")
      .upsert({
        user_id: params.userId,
        prompt_id: params.promptId,
        inputs_hash: params.inputsHash,
        model: params.model,
        response_body: parsed,
        prompt_tokens: params.promptTokens,
        completion_tokens: params.completionTokens,
        expires_at: expiresAt,
      }, { onConflict: "user_id,prompt_id,inputs_hash" });
  } catch (_) {
    // swallow
  }
}

// =====================================================================
// PR 3 (Tier 2): Registry-as-truth for system prompts
// =====================================================================
// We are migrating ownership of system prompt text from the iOS client to
// the public.prompt_templates table. The allowlist below names the
// surfaces that have been (a) byte-equality verified against iOS runtime
// output and (b) cleaned of Swift-isms in the cleanup migration
// (20260517120000_normalize_prompt_templates.sql, SHA f4f0cbc).
//
// For these surfaces the ai-proxy will look up the active template from
// the registry and replace body.messages[0].content with it BEFORE
// forwarding to OpenRouter — but only when messages[0] is a system
// message AND its current content matches the registry byte-for-byte.
// That guard makes this swap a provable no-op at runtime: if iOS ever
// sends a different system prompt for an allowlisted surface, we leave
// the body alone and log the call with promptVersion = null so we can
// catch drift in telemetry.
//
// PR 3 minimum scope: only the system_template is swapped. The
// prompt_templates.model column is intentionally NOT consulted yet;
// resolveModel() above keeps using the hardcoded MODEL_ROUTING map.
export const REGISTRY_AUTHORITATIVE_PROMPTS: Set<string> = new Set([
  "lab_parse",
  "nutrition_ai",
  "bloodwork_interp",
  "journey_narrative",
  "story_mode",
]);

// Look up the active system template for a prompt_id. Returns null on
// miss / error — a lookup failure must never block the request. The
// caller is expected to fall back to the iOS-supplied system prompt
// when this returns null.
// deno-lint-ignore no-explicit-any
export async function resolvePromptTemplate(admin: any, promptId: string): Promise<
  { template: string; version: number } | null
> {
  try {
    const { data } = await admin
      .from("prompt_templates")
      .select("system_template, version")
      .eq("prompt_id", promptId)
      .eq("active", true)
      .maybeSingle();
    if (!data || typeof data.system_template !== "string") return null;
    const version = Number(data.version);
    if (!Number.isFinite(version)) return null;
    return { template: data.system_template, version };
  } catch (_) {
    return null;
  }
}
