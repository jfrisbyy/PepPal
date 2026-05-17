-- PR 6: ai_call_log context attribution columns
--
-- Adds two nullable columns so we can measure context-injection hit rate
-- and freshness on a per-call basis. NULL means: this call did not have
-- context injected (either the prompt_id is not in TEMPLATES_WITH_CONTEXT,
-- or the rebuild RPC errored, or this was a cache hit so the upstream
-- call was skipped entirely). Non-NULL means the row was injected with
-- user_context generated at context_generated_at, which was
-- context_age_seconds old at the moment of the call.
--
-- Both columns are nullable. Historical rows stay NULL. Non-whitelisted
-- prompt_ids stay NULL. Cache hits stay NULL. Only successful injection
-- paths populate them.

ALTER TABLE public.ai_call_log
  ADD COLUMN IF NOT EXISTS context_generated_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS context_age_seconds  integer     NULL;

COMMENT ON COLUMN public.ai_call_log.context_generated_at IS
  'When user_context was generated for this call. NULL means context was not injected.';
COMMENT ON COLUMN public.ai_call_log.context_age_seconds IS
  'Age of injected user_context at call time. NULL means context was not injected.';
