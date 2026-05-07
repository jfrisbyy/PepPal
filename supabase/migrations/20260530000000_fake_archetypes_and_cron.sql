-- ============================================================
-- Fake-account scaling: archetype labels + twice-daily auto-log
-- cron tick + helper indexes used by the new bulk populate flow.
-- ============================================================

-- 1) Archetype label/tagline for fake personas. Used by the in-app
--    Fake Account Switcher so operators can see "who is who" at a
--    glance before signing in as that persona.
alter table public.profiles
    add column if not exists archetype_label text;

alter table public.profiles
    add column if not exists archetype_tagline text;

create index if not exists profiles_test_user_idx
    on public.profiles(is_test_user)
    where is_test_user = true;

-- 2) pg_cron + pg_net for the twice-daily auto-log tick. Both are
--    available on Supabase by default — guarded with IF NOT EXISTS
--    so this migration is safe on local dev.
do $$
begin
    create extension if not exists pg_cron with schema extensions;
exception when others then null;
end $$;

do $$
begin
    create extension if not exists pg_net with schema extensions;
exception when others then null;
end $$;

-- 3) Settings used to call the super-action edge function from cron.
--    Operators set these via `alter database ... set` once; the cron
--    job reads them at fire time. Safe to leave unset on local dev.
do $$
begin
    perform 1
    from pg_settings
    where name = 'app.supabase_url';
exception when others then null;
end $$;

-- 4) Schedule the auto-log tick — twice a day, 13:30 UTC and 01:30 UTC.
--    The job posts to super-action with action=fakeDailyAutoLog.
do $$
declare
    base_url text := current_setting('app.supabase_url', true);
    cron_secret text := current_setting('app.cron_secret', true);
begin
    if base_url is null or base_url = '' then
        return; -- not configured on this environment; skip
    end if;

    -- Drop prior jobs (idempotent re-deploy)
    perform cron.unschedule(jobid)
    from cron.job
    where jobname in ('fake-auto-log-am', 'fake-auto-log-pm');

    perform cron.schedule(
        'fake-auto-log-am',
        '30 13 * * *',
        format($cmd$
            select net.http_post(
                url := %L,
                headers := jsonb_build_object(
                    'content-type', 'application/json',
                    'authorization', %L
                ),
                body := jsonb_build_object(
                    'action', 'fakeDailyAutoLog',
                    'payload', jsonb_build_object('secret', %L)
                )
            );
        $cmd$,
        base_url || '/functions/v1/super-action',
        'Bearer ' || coalesce(current_setting('app.service_role_key', true), ''),
        coalesce(cron_secret, '')
        )
    );

    perform cron.schedule(
        'fake-auto-log-pm',
        '30 1 * * *',
        format($cmd$
            select net.http_post(
                url := %L,
                headers := jsonb_build_object(
                    'content-type', 'application/json',
                    'authorization', %L
                ),
                body := jsonb_build_object(
                    'action', 'fakeDailyAutoLog',
                    'payload', jsonb_build_object('secret', %L)
                )
            );
        $cmd$,
        base_url || '/functions/v1/super-action',
        'Bearer ' || coalesce(current_setting('app.service_role_key', true), ''),
        coalesce(cron_secret, '')
        )
    );
exception when others then
    -- pg_cron may not be enabled in some environments; ignore.
    null;
end $$;
