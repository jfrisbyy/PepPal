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

