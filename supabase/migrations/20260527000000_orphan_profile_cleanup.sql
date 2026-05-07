-- ============================================================
-- Fix: "insert or update on table follows violates foreign key
-- constraint follows_following_id_fkey" when following a seeded
-- test profile.
--
-- Root cause: the profiles table contained rows whose `id` did
-- NOT have a matching auth.users row (left over from a previous
-- clearTestFriends partial run, or from a profile that was
-- inserted directly without first creating the auth user).
-- follows.following_id references auth.users(id), so any attempt
-- to follow such an orphan profile blows up with the FK error.
--
-- This migration:
--   1. Hard-deletes orphan profile rows (and any follows / follow
--      requests that point at non-existent users — we wouldn't be
--      able to repair those anyway).
--   2. Re-asserts the profiles.id -> auth.users(id) ON DELETE
--      CASCADE foreign key so future auth.user deletions cannot
--      leave profile orphans behind.
-- ============================================================

-- 1) Clean orphan rows --------------------------------------------------

-- Delete follows pointing at users that no longer exist (either side).
delete from public.follows f
where not exists (select 1 from auth.users u where u.id = f.follower_id)
   or not exists (select 1 from auth.users u where u.id = f.following_id);

-- Same for pending follow requests.
do $$
begin
    if to_regclass('public.follow_requests') is not null then
        execute $sql$
            delete from public.follow_requests fr
            where not exists (select 1 from auth.users u where u.id = fr.requester_id)
               or not exists (select 1 from auth.users u where u.id = fr.target_id)
        $sql$;
    end if;
end$$;

-- Finally drop the orphan profile rows themselves.
delete from public.profiles p
where not exists (select 1 from auth.users u where u.id = p.id);

-- 2) Re-assert FK with ON DELETE CASCADE --------------------------------

do $$
declare
    fk_name text;
begin
    -- Drop any existing FK on profiles.id (name unknown across envs).
    for fk_name in
        select conname
        from pg_constraint
        where conrelid = 'public.profiles'::regclass
          and contype  = 'f'
          and conkey   = array[(
              select attnum from pg_attribute
              where attrelid = 'public.profiles'::regclass
                and attname  = 'id'
          )::smallint]
    loop
        execute format('alter table public.profiles drop constraint %I', fk_name);
    end loop;

    alter table public.profiles
        add constraint profiles_id_fkey
        foreign key (id)
        references auth.users(id)
        on delete cascade;
end$$;
