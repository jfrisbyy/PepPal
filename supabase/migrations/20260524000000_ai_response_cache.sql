-- ai_response_cache: 24h response cache (configurable up to 7 days) used by
-- the ai-proxy edge function. Callers opt in by passing `cache_key` in the
-- request body. The proxy hashes (model + key) into key_hash so the original
-- key never lands at rest.
--
-- Used for: nutrition text descriptions ("estimate calories for grilled
-- chicken bowl"), barcode-derived nutrition lookups, and any other deterministic
-- AI request whose answer is the same for every user.

create table if not exists public.ai_response_cache (
    key_hash text primary key,
    model text not null,
    response_body text not null,
    content_type text not null default 'application/json',
    created_at timestamptz not null default now(),
    expires_at timestamptz not null
);

create index if not exists ai_response_cache_expires_idx
    on public.ai_response_cache (expires_at);

alter table public.ai_response_cache enable row level security;

-- No client access whatsoever. Only the edge function (service role) reads
-- and writes. Lock everything down.
revoke all on public.ai_response_cache from anon;
revoke all on public.ai_response_cache from authenticated;

-- Best-effort sweeper. Cron isn't required — the proxy filters on
-- expires_at on every read so stale rows never leak. This function exists
-- so an admin can reclaim space ad-hoc if the table grows.
create or replace function public.ai_response_cache_purge_expired()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    deleted_count integer;
begin
    delete from public.ai_response_cache
    where expires_at < now();
    get diagnostics deleted_count = row_count;
    return deleted_count;
end $$;

revoke all on function public.ai_response_cache_purge_expired() from public;
revoke all on function public.ai_response_cache_purge_expired() from authenticated;
