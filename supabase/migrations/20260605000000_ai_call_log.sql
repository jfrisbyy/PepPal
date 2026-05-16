-- ai_call_log: per-call attribution telemetry for the ai-proxy edge function.
-- Each row represents one attempted OpenRouter call (or a cache hit) on
-- behalf of an authenticated user. We log structured metadata only — never
-- the prompt body, response body, or completion text. See RLS_AUDIT.md
-- for the updated logging-hygiene contract.
--
-- Used for: per-prompt cost attribution, cache-hit-rate analysis, latency
-- monitoring, and model-routing decisions in subsequent PRs. Token counts
-- mirror what ai_usage_increment() persists in ai_usage_daily but preserve
-- per-call granularity for cost-per-prompt analysis.

create table if not exists public.ai_call_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  prompt_id text not null default 'unknown',
  model text not null,
  status integer not null,
  cache_hit boolean not null default false,
  prompt_tokens integer not null default 0,
  completion_tokens integer not null default 0,
  cost_usd numeric(10, 6) not null default 0,
  latency_ms integer not null default 0,
  error_code text,
  created_at timestamptz not null default now()
);

create index if not exists ai_call_log_user_created_idx
  on public.ai_call_log (user_id, created_at desc);

create index if not exists ai_call_log_prompt_created_idx
  on public.ai_call_log (prompt_id, created_at desc);

create index if not exists ai_call_log_created_idx
  on public.ai_call_log (created_at desc);

alter table public.ai_call_log enable row level security;

-- Mirror ai_usage_daily pattern: owner can read their own rows, all writes
-- revoked from clients. The edge function (service role) is the only writer.
create policy "ai_call_log_owner_select"
  on public.ai_call_log
  for select
  to authenticated
  using (auth.uid() = user_id);

revoke insert, update, delete on public.ai_call_log from anon;
revoke insert, update, delete on public.ai_call_log from authenticated;

-- Retention sweeper. Cron isn't required — admin can call this ad-hoc.
-- 90-day default retention; bump if/when we add longer-window dashboards.
create or replace function public.ai_call_log_purge_old(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  delete from public.ai_call_log
  where created_at < now() - make_interval(days => p_days);
  get diagnostics deleted_count = row_count;
  return deleted_count;
end $$;

revoke all on function public.ai_call_log_purge_old(integer) from public;
revoke all on function public.ai_call_log_purge_old(integer) from authenticated;
