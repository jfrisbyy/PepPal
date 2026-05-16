-- ============================================================
-- AI insights cache: persistent dedupe for AI proxy responses
-- keyed on (user_id, prompt_id, inputs_hash). When the ai-proxy
-- sees a request whose prompt_id is in its DEDUPE_ENABLED set
-- and finds a non-expired row, it replays the cached response
-- without forwarding to OpenRouter. Target: Sonnet 4.6 spend on
-- insights_agent invocations where inputs have not changed.
-- ============================================================

create table if not exists public.ai_insights_cache (
  user_id uuid not null references auth.users(id) on delete cascade,
  prompt_id text not null check (char_length(prompt_id) between 1 and 64),
  inputs_hash text not null check (char_length(inputs_hash) between 16 and 128),
  model text not null,
  response_body jsonb not null,
  prompt_tokens int,
  completion_tokens int,
  generated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  primary key (user_id, prompt_id, inputs_hash)
);

-- Latest-row lookup per (user, prompt_id).
create index if not exists ai_insights_cache_user_prompt_generated_idx
  on public.ai_insights_cache(user_id, prompt_id, generated_at desc);

-- Cheap purge filter.
create index if not exists ai_insights_cache_expires_at_idx
  on public.ai_insights_cache(expires_at);

alter table public.ai_insights_cache enable row level security;

-- Users can read their own cache rows (lets the app inspect / debug
-- if we ever surface a "from cache" badge). Service role bypasses RLS
-- and is what the edge function uses for writes.
drop policy if exists "ai_insights_cache_self_read" on public.ai_insights_cache;
create policy "ai_insights_cache_self_read"
  on public.ai_insights_cache for select to authenticated
  using (auth.uid() = user_id);

-- Retention: drop any row whose TTL has elapsed. The edge function does
-- not need to call this synchronously; a pg_cron job (or future Tier 4
-- task) can run it on a schedule. Safe to call from psql / SQL editor.
create or replace function public.ai_insights_cache_purge_expired()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  removed int;
begin
  delete from public.ai_insights_cache where expires_at <= now();
  get diagnostics removed = row_count;
  return removed;
end;
$$;

-- Lock the function down: only service_role can execute it. The edge
-- function uses the service role key; humans should call it via the
-- SQL editor as postgres / supabase_admin.
revoke all on function public.ai_insights_cache_purge_expired() from public;
revoke all on function public.ai_insights_cache_purge_expired() from anon, authenticated;
grant execute on function public.ai_insights_cache_purge_expired() to service_role;
