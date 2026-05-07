-- ============================================================
-- post_comments: heal legacy column shapes that broke inserts.
--
-- Earlier deployments of this table shipped with a `body` or
-- `text` column declared NOT NULL with no default. The current
-- client only writes `content`, so any environment that still
-- has the legacy column rejects every insert with
--   null value in column "body" violates not-null constraint.
--
-- This migration normalises the table so inserts that only
-- supply `content` always succeed:
--   1. Make sure `content` exists with default ''.
--   2. If legacy `body` / `text` columns exist, drop their
--      NOT NULL constraint, default them to '', and backfill
--      any existing nulls from `content`.
--   3. Install a BEFORE INSERT/UPDATE trigger that mirrors the
--      writer's value across all three columns so any reader
--      sees the same string.
--
-- Forward-only and idempotent.
-- ============================================================

BEGIN;

-- 1. Canonical column.
alter table public.post_comments
    add column if not exists content text not null default '';

-- 2. Relax legacy columns if they exist.
do $relax$
declare
    col text;
begin
    foreach col in array array['body', 'text'] loop
        if exists (
            select 1
            from information_schema.columns
            where table_schema = 'public'
              and table_name = 'post_comments'
              and column_name = col
        ) then
            execute format(
                'alter table public.post_comments alter column %I drop not null',
                col
            );
            execute format(
                'alter table public.post_comments alter column %I set default %L',
                col, ''
            );
            execute format(
                'update public.post_comments set %I = coalesce(nullif(%I, %L), content, %L) where %I is null or %I = %L',
                col, col, '', '', col, col, ''
            );
        end if;
    end loop;
end
$relax$;

-- 3. Mirror trigger so legacy columns stay in sync with content.
create or replace function public.post_comments_sync_text_columns()
returns trigger
language plpgsql
as $fn$
declare
    has_body boolean;
    has_text boolean;
    body_val text;
    text_val text;
    canonical text;
    rec_json jsonb;
begin
    select exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'post_comments'
          and column_name = 'body'
    ) into has_body;

    select exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'post_comments'
          and column_name = 'text'
    ) into has_text;

    rec_json := to_jsonb(NEW);

    canonical := nullif(NEW.content, '');
    if canonical is null and has_body then
        body_val := rec_json ->> 'body';
        canonical := nullif(body_val, '');
    end if;
    if canonical is null and has_text then
        text_val := rec_json ->> 'text';
        canonical := nullif(text_val, '');
    end if;
    canonical := coalesce(canonical, '');

    NEW.content := canonical;

    if has_body then
        rec_json := jsonb_set(rec_json, '{body}', to_jsonb(canonical), true);
    end if;
    if has_text then
        rec_json := jsonb_set(rec_json, '{text}', to_jsonb(canonical), true);
    end if;

    NEW := jsonb_populate_record(NEW, rec_json);
    return NEW;
end
$fn$;

drop trigger if exists post_comments_sync_text_columns on public.post_comments;
create trigger post_comments_sync_text_columns
before insert or update on public.post_comments
for each row execute function public.post_comments_sync_text_columns();

COMMIT;
