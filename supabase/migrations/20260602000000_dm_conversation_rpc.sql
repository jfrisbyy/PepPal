-- ---------------------------------------------------------------------------
-- DM conversation creation RPC.
--
-- The `conv_participants_self_insert` RLS policy (introduced in
-- 20260518000000_rls_storage_abuse_hardening.sql) only allows a caller to
-- insert a participant row for themselves (`user_id = auth.uid()`). That
-- correctly blocks a stranger from yanking a third party into a private
-- conversation, but it also prevents the legitimate "start a DM with X"
-- flow from inserting both participants in one shot from the client.
--
-- The result was that `MessagingService.findOrCreateConversation` succeeded
-- in inserting the `conversations` row and the *self* participant row, then
-- silently failed (RLS) on the *other* participant row. The whole
-- transaction threw, the client never got a conversation id, and every
-- subsequent send was marked "failed — tap to retry".
--
-- This SECURITY DEFINER function does the create-or-find safely on the
-- server, with an explicit `auth.uid()` check so a caller still can't
-- forge a conversation on someone else's behalf.
-- ---------------------------------------------------------------------------

create or replace function public.find_or_create_dm_conversation(
    p_other_user_id uuid
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_existing uuid;
    v_new uuid;
begin
    if v_me is null then
        raise exception 'not authenticated';
    end if;

    if p_other_user_id is null then
        raise exception 'other user id is required';
    end if;

    if p_other_user_id = v_me then
        raise exception 'cannot start a conversation with yourself';
    end if;

    -- Existing 1:1 conversation: a conversations row that has *exactly*
    -- these two participants (no group threads).
    select c.id
      into v_existing
      from public.conversations c
     where exists (
            select 1 from public.conversation_participants p
             where p.conversation_id = c.id and p.user_id = v_me
         )
       and exists (
            select 1 from public.conversation_participants p
             where p.conversation_id = c.id and p.user_id = p_other_user_id
         )
       and (
            select count(*) from public.conversation_participants p
             where p.conversation_id = c.id
         ) = 2
     limit 1;

    if v_existing is not null then
        return v_existing;
    end if;

    insert into public.conversations default values
        returning id into v_new;

    insert into public.conversation_participants (conversation_id, user_id)
        values (v_new, v_me), (v_new, p_other_user_id);

    return v_new;
end;
$$;

revoke all on function public.find_or_create_dm_conversation(uuid) from public;
grant execute on function public.find_or_create_dm_conversation(uuid) to authenticated;
