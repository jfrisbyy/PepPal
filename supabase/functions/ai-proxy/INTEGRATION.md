# ai-proxy: ai_call_log integration spec

This document describes the changes Rork (or any contributor) needs to apply
to `supabase/functions/ai-proxy/index.ts` to enable per-call attribution
telemetry. The migration (`20260605000000_ai_call_log.sql`) and the helper
module (`_call_log.ts`) are already in place on this branch.

The integration is intentionally additive: every new insert is wrapped in
`try/catch` so a telemetry failure cannot break a user-facing request. If
this PR is reverted, the function still works exactly as before — the new
table and helper become dead code.

## Summary of changes to index.ts

1. **Import the helper** at the top of the file, after the supabase-js
   import line.
2. **Capture timing and prompt_id** immediately after the JWT is validated
   and `userId` is known.
3. **Log one row on cache hit** before the early-return response.
4. **Log one row on upstream success** after `ai_usage_increment` is called.
5. **Log one row on upstream error** in the existing `!upstream.ok` branch.

Auth failures, bad-JSON failures, and rate-limit / daily-budget rejections
are intentionally NOT logged here. Those code paths run before we know which
prompt was being attempted, and the user attribution is unreliable. They
continue to log to stderr via the existing `console.error` calls.

## Patch 1: imports

Find this line near the top of `index.ts`:

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
```

Add immediately below it:

```ts
import { extractPromptId, logAiCall } from "./_call_log.ts";
```

## Patch 2: capture timing and prompt_id

After the JWT validation block, just after `userId = userJson.id;` is
assigned and before `const admin = createClient(...)` is constructed, add:

```ts
const startedAt = Date.now();
const promptId = extractPromptId(req);
```

These two variables are used by all three log-call sites below.

## Patch 3: log on cache hit

In the response-cache lookup block, the current code returns early on a
cache hit with:

```ts
if (cached?.response_body) {
  return new Response(cached.response_body as string, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": (cached.content_type as string) ?? "application/json",
      "X-AIProxy-Cache": "HIT",
    },
  });
}
```

Replace it with:

```ts
if (cached?.response_body) {
  try {
    await logAiCall(admin, {
      userId,
      promptId,
      model,
      status: 200,
      cacheHit: true,
      promptTokens: 0,
      completionTokens: 0,
      latencyMs: Date.now() - startedAt,
    });
  } catch (_) {
    // Telemetry failure must never block a cache hit.
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
```

## Patch 4: log on upstream success

In the `if (upstream.ok)` block, after the existing token-accounting and
cache-write logic, add a final log call. Find the closing brace of the
`if (upstream.ok)` block and insert immediately before it:

```ts
try {
  // Re-parse for token counts; cheap (`text` is already in memory).
  let promptTokens = 0;
  let completionTokens = 0;
  try {
    const parsed = JSON.parse(text) as {
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };
    promptTokens = Math.max(0, Math.floor(Number(parsed?.usage?.prompt_tokens ?? 0)));
    completionTokens = Math.max(0, Math.floor(Number(parsed?.usage?.completion_tokens ?? 0)));
  } catch (_) {
    // Non-JSON success response (rare). Token counts stay 0.
  }
  await logAiCall(admin, {
    userId,
    promptId,
    model,
    status: upstream.status,
    cacheHit: false,
    promptTokens,
    completionTokens,
    latencyMs: Date.now() - startedAt,
  });
} catch (_) {
  // Telemetry failure must never block a successful response.
}
```

## Patch 5: log on upstream error

In the existing `else` branch (the `!upstream.ok` path that logs to
stderr), after the `console.error` call, add:

```ts
try {
  await logAiCall(admin, {
    userId,
    promptId,
    model,
    status: upstream.status,
    cacheHit: false,
    promptTokens: 0,
    completionTokens: 0,
    latencyMs: Date.now() - startedAt,
    errorCode: `upstream_${upstream.status}`,
  });
} catch (_) {
  // Telemetry failure must never escalate an already-errored request.
}
```

## Why we don't log on fetch failure (catch block at bottom)

The bottom `catch (err)` block fires when the `fetch(OPENROUTER_URL, ...)`
call itself throws — e.g. DNS failure, network partition. We could log
those too, but they're already in stderr and adding a DB write inside a
catch block raises the risk of a cascading failure where the DB is also
unreachable. Out of scope for PR 2; revisit in PR 3 if needed.

## iOS / Rork client follow-up

The proxy now reads `X-Epti-Prompt-Id` from incoming requests. Until the
iOS client is updated to send it, every logged row will have
`prompt_id = 'unknown'`. Rork should:

1. Add an `extension URLRequest` or shared HTTP wrapper that attaches the
   header based on which service is calling the proxy.
2. Annotate each of the ~14 AI call sites with a stable `prompt_id` string.
   Suggested ids (lowercase, snake_case, 1-64 chars):
   - `daily_brief`
   - `insights_agent`
   - `finn_chat`
   - `peptide_chat`
   - `ai_program`
   - `bloodwork_interp`
   - `lab_parse`
   - `nutrition_ai`
   - `vial_label_scan`
   - `vial_integrity`
   - `story_mode`
   - `journey_narrative`
   - `add_vial_flow`
   - `global_search_extras`

These are advisory; the proxy accepts any string matching
`/^[a-z0-9_]{1,64}$/` and falls back to `'unknown'` for anything else, so
adding new ids in the future requires no server change.

## Verification after deploy

1. `select count(*) from public.ai_call_log;` — should be 0 immediately
   after migration apply, climbing as soon as the patched function is
   deployed.
2. `select prompt_id, count(*) from public.ai_call_log group by 1;` — until
   Rork wires the header, expect everything to be `unknown`.
3. `select cache_hit, count(*) from public.ai_call_log group by 1;` — the
   ratio gives us the cache-hit-rate metric Tier 1 cares about.
4. `select model, sum(cost_usd) from public.ai_call_log where created_at >
   now() - interval '1 day' group by 1 order by 2 desc;` — per-model daily
   spend.
5. After Rork lands the header: `select prompt_id, sum(cost_usd) from
   public.ai_call_log where created_at > now() - interval '1 day' group by
   1 order by 2 desc;` — this is the attribution number PR 1 needs.

## Rollback

Pure roll-back: revert this PR. The table will keep its rows but nothing
will read or write to it. To reclaim the table:

```sql
drop function if exists public.ai_call_log_purge_old(integer);
drop table if exists public.ai_call_log;
```

