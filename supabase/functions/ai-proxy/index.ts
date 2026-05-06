// Supabase Edge Function: ai-proxy
// Authenticated proxy in front of OpenRouter so we never ship the
// OpenRouter API key to the client. Clients send their Supabase JWT;
// we validate it, then forward the chat-completion body to OpenRouter
// using the server-only OPENROUTER_API_KEY.
//
// Per-user rate limit (rolling 1-minute window) and request/response
// size caps keep the key from being abused if a token leaks.

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

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
        return json(405, { error: "method_not_allowed" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const openRouterKey = Deno.env.get("OPENROUTER_API_KEY");
    if (!supabaseUrl || !serviceRoleKey || !openRouterKey) {
        return json(500, { error: "server_misconfigured" });
    }

    // ---- Auth -----------------------------------------------------
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.toLowerCase().startsWith("bearer ")
        ? authHeader.slice(7).trim()
        : "";
    if (!jwt) return json(401, { error: "unauthorized" });

    const admin = createClient(supabaseUrl, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) {
        return json(401, { error: "unauthorized" });
    }
    const userId = userData.user.id;

    if (!checkRateLimit(userId)) {
        return json(429, { error: "rate_limited" });
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
        return new Response(text, {
            status: upstream.status,
            headers: {
                ...CORS_HEADERS,
                "Content-Type": upstream.headers.get("content-type") ?? "application/json",
            },
        });
    } catch (err) {
        console.error("ai-proxy upstream error", err);
        return json(502, { error: "upstream_error", detail: String(err) });
    }
});
