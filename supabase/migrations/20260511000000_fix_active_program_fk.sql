-- ============================================================
-- Fix: "insert or update on table profiles violates foreign key
-- constraint profiles_active_program_id_fkey"
--
-- An older/manual migration added profiles.active_program_id with
-- a strict FK to training_programs(id). Some trigger or client
-- path is setting this column to a UUID that doesn't exist in
-- training_programs, which blocks profile updates whenever a
-- user saves a program.
--
-- Our app does not rely on profiles.active_program_id; it tracks
-- the active program on the training_programs row itself
-- (is_active = true). To stop the FK from blocking saves we:
--   1) Null out any stale active_program_id values that no longer
--      reference an existing training_programs row.
--   2) Drop the strict FK and re-create it as ON DELETE SET NULL
--      and DEFERRABLE INITIALLY DEFERRED, so trigger-based or
--      same-transaction inserts no longer fail.
-- ============================================================

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'profiles'
          and column_name = 'active_program_id'
    ) then
        -- 1) Clear stale references so the new FK can be applied.
        update public.profiles p
        set active_program_id = null
        where active_program_id is not null
          and not exists (
              select 1 from public.training_programs t
              where t.id = p.active_program_id
          );

        -- 2) Drop the existing FK constraint (any name) on this column.
        if exists (
            select 1
            from pg_constraint c
            join pg_class t on t.oid = c.conrelid
            join pg_namespace n on n.oid = t.relnamespace
            where n.nspname = 'public'
              and t.relname = 'profiles'
              and c.contype = 'f'
              and c.conname = 'profiles_active_program_id_fkey'
        ) then
            alter table public.profiles
                drop constraint profiles_active_program_id_fkey;
        end if;

        -- 3) Re-add a lenient FK: nullify on delete, deferrable so
        --    triggers running in the same transaction as a program
        --    insert won't race the FK check.
        alter table public.profiles
            add constraint profiles_active_program_id_fkey
            foreign key (active_program_id)
            references public.training_programs(id)
            on delete set null
            deferrable initially deferred;
    end if;
end
$$;
