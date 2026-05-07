// Supabase Edge Function: ai-proxy
// Authenticated proxy in front of OpenRouter so we never ship the
// OpenRouter API key to the client. Clients send their Supabase JWT;
// we validate it, then forward the chat-completion body to OpenRouter
// using the server-only OPENROUTER_API_KEY.
//
// Hardening applied:
//   - Per-user 30 req/min rate limit (rolling 1-minute window).
//   - Per-user daily token budget (default 50_000 tokens/day, overridable
//     per user via ai_usage_daily.daily_token_limit).
//   - Model allow-list to prevent calling exotic / expensive models.
//   - 8 MB request body cap (vision payloads).
//   - Logging hygiene: NEVER log prompts/responses/tokens. On upstream
//     failure we log only { status, model, userIdHash, errorBodySnippet }.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MAX_REQUEST_BYTES = 8 * 1024 * 1024; // 8 MB (vision payloads)
const RATE_LIMIT_PER_MIN = 30;
const DEFAULT_DAILY_TOKEN_LIMIT = 50_000;

// Allow-list of models that may be requested through the proxy. Keeps
// callers from billing exotic / expensive models against our key.
const ALLOWED_MODELS = new Set<string>([
    "anthropic/claude-haiku-4.5",
    "anthropic/claude-sonnet-4.6",
    "openai/gpt-4o",
    "openai/gpt-4o-2024-11-20",
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

    // Service-role client is still used for token-budget RPCs below.
    const admin = createClient(supabaseUrl, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false },
    });

    if (!checkRateLimit(userId)) {
        return json(429, { error: "rate_limited" });
    }

    // ---- Daily token budget --------------------------------------
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
    if (!model || !ALLOWED_MODELS.has(model)) {
        return json(400, { error: "model_not_allowed", model });
    }
    if (!Array.isArray(body.messages)) {
        return json(400, { error: "missing_messages" });
    }

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

        // Best-effort token accounting. Only parse on success; never log
        // the response body itself.
        if (upstream.ok) {
            try {
                const parsed = JSON.parse(text) as {
                    usage?: {
                        prompt_tokens?: number;
                        completion_tokens?: number;
                    };
                };
                const prompt = Number(parsed?.usage?.prompt_tokens ?? 0);
                const completion = Number(parsed?.usage?.completion_tokens ?? 0);
                if (prompt > 0 || completion > 0) {
                    await admin.rpc("ai_usage_increment", {
                        p_user_id: userId,
                        p_prompt_tokens: Math.max(0, Math.floor(prompt)),
                        p_completion_tokens: Math.max(0, Math.floor(completion)),
                    });
                }
            } catch (_) {
                // Token usage is non-critical; don't fail the request.
            }
        } else {
            // Log only the metadata + a trimmed snippet of the upstream
            // error body (NOT the request body, NOT the response body of
            // a successful call). 512-char cap to keep noise out of logs.
            const snippet = text.length > 512 ? text.slice(0, 512) + "…" : text;
            console.error(JSON.stringify({
                event: "ai_proxy_upstream_error",
                status: upstream.status,
                model,
                user: userHash,
                error: snippet,
            }));
        }

        return new Response(text, {
            status: upstream.status,
            headers: {
                ...CORS_HEADERS,
                "Content-Type": upstream.headers.get("content-type") ?? "application/json",
            },
        });
    } catch (err) {
        console.error(JSON.stringify({
            event: "ai_proxy_fetch_failed",
            model,
            user: userHash,
            error: String(err).slice(0, 256),
        }));
        return json(502, { error: "upstream_error" });
    }
});
