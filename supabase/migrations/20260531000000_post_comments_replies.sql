-- ============================================================
-- post_comments: support threaded replies via parent_comment_id.
-- Forward-only and idempotent.
-- ============================================================

BEGIN;

alter table public.post_comments
    add column if not exists parent_comment_id uuid
        references public.post_comments(id) on delete cascade;

create index if not exists post_comments_parent_idx
    on public.post_comments(parent_comment_id, created_at asc);

COMMIT;
