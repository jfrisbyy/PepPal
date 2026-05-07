-- ============================================================
-- Long-horizon user memory.
-- One compact, AI-curated narrative per user that the deep
-- (Sonnet) brief reads + rewrites at the end of every deep run,
-- and the fast (Haiku) brief reads only. Plus a structured
-- list of significant events (bloodwork uploads, programs
-- started/abandoned, large weight changes, escalating side
-- effects) that we never want the model to forget.
-- ============================================================

create table if not exists public.user_long_term_memory (
    user_id uuid primary key references auth.users(id) on delete cascade,
    -- Sonnet-curated narrative (~3-4 KB cap, ~1000 tokens). Plain text,
    -- no markdown. Rewritten end-to-end on every deep run.
    profile_memo text not null default '',
    -- Capped jsonb history of prior memo versions for diff/rollback,
    -- shape: [{ at: timestamptz, by_model: text, memo: text }]. Capped
    -- at 10 entries by the writer.
    memo_versions jsonb not null default '[]'::jsonb,
    -- Auto-detected significant events the model should always know
    -- about. Shape: [{ id: uuid, at: date, type: text, summary: text,
    --                  values?: jsonb, source?: text }]
    -- Capped at 100 entries by the writer (rolling, oldest dropped).
    significant_events jsonb not null default '[]'::jsonb,
    last_updated_at timestamptz not null default now(),
    last_updated_by_model text
);

create index if not exists user_long_term_memory_updated_idx
    on public.user_long_term_memory(last_updated_at desc);

alter table public.user_long_term_memory enable row level security;

drop policy if exists "user_long_term_memory_self_rw" on public.user_long_term_memory;
create policy "user_long_term_memory_self_rw"
on public.user_long_term_memory for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Touch updated_at on every write (matches existing pattern in
-- 20260507000000_ai_briefings_persistence.sql).
drop trigger if exists user_long_term_memory_touch on public.user_long_term_memory;
create trigger user_long_term_memory_touch
before update on public.user_long_term_memory
for each row execute function public.touch_updated_at();

-- Rename last_updated_at via the same touch trigger isn't ideal —
-- clients set it explicitly on writes. The trigger above touches the
-- legacy `updated_at` column if present; absent here, it is a no-op.
