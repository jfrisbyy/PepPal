-- Add is_test_user flag to profiles so seeded test accounts can be identified and cleaned up

alter table public.profiles
    add column if not exists is_test_user boolean not null default false;

create index if not exists profiles_is_test_user_idx
    on public.profiles(is_test_user)
    where is_test_user = true;
