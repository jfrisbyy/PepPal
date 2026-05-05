-- ============================================================
-- Auto-create profiles row for every auth.users entry, and
-- backfill any users who don't have one yet. This fixes
-- foreign key violations like "insert or update on table
-- training_programs violates foreign key constraint
-- training_programs_user_id_fkey" when an authenticated user
-- has no matching profiles row.
-- ============================================================

-- 1) Backfill: insert a profile for every existing auth.user
--    that doesn't have one. We only set the id; all other
--    columns can remain at their defaults / null and be
--    populated by the onboarding flow.
insert into public.profiles (id)
select u.id
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;

-- 2) Trigger function: create a profile row whenever a new
--    auth.users row is inserted (sign up, magic link, OAuth).
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id)
    values (new.id)
    on conflict (id) do nothing;
    return new;
end;
$$;

-- 3) Attach the trigger to auth.users. Drop first so this
--    migration is idempotent across re-runs.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_auth_user();
