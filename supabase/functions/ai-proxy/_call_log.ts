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
