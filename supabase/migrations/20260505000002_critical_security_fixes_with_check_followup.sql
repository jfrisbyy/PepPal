-- =============================================================================
-- PepPal / EPTI — CRIT-3 follow-up: WITH CHECK for non-standard UPDATE policies
-- =============================================================================
-- Companion to 20260505000001_critical_security_fixes.sql.
-- Applies WITH CHECK clauses to the 11 UPDATE policies that the bulk loop
-- correctly skipped because their qual didn't match the standard
-- 'auth.uid() = user_id' shape.
--
-- For each policy, WITH CHECK mirrors USING — so a user who can target a row
-- (USING) is also constrained on what the row can become (WITH CHECK).
--
-- Applied to production Supabase project fyvhtfbyothjozfwjcod on 2026-05-05.
-- Verified post-apply: zero UPDATE policies in public schema remain without
-- a WITH CHECK clause.
-- =============================================================================

BEGIN;

-- ---- Category A: direct ownership via non-user_id column ---------------------

ALTER POLICY "Users can update own profile" ON public.profiles
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

ALTER POLICY "Circle owners can update" ON public.circles
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

ALTER POLICY "Users can update own programs" ON public.market_programs
  USING ((SELECT auth.uid()) = creator_id)
  WITH CHECK ((SELECT auth.uid()) = creator_id);

ALTER POLICY "Users can update their received requests" ON public.friend_requests
  USING ((SELECT auth.uid()) = receiver_id)
  WITH CHECK ((SELECT auth.uid()) = receiver_id);

ALTER POLICY "follow_requests update target" ON public.follow_requests
  USING ((SELECT auth.uid()) = target_id)
  WITH CHECK ((SELECT auth.uid()) = target_id);

-- ---- Category B: indirect ownership via parent (EXISTS) ----------------------

ALTER POLICY "Users can update own protocol compounds" ON public.protocol_compounds
  USING (
    EXISTS (
      SELECT 1 FROM public.protocols
       WHERE protocols.id = protocol_compounds.protocol_id
         AND protocols.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.protocols
       WHERE protocols.id = protocol_compounds.protocol_id
         AND protocols.user_id = (SELECT auth.uid())
    )
  );

ALTER POLICY "Users can update own program days" ON public.program_days
  USING (
    EXISTS (
      SELECT 1 FROM public.training_programs tp
       WHERE tp.id = program_days.program_id
         AND tp.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.training_programs tp
       WHERE tp.id = program_days.program_id
         AND tp.user_id = (SELECT auth.uid())
    )
  );

ALTER POLICY "Users can update own biomarker results" ON public.biomarker_results
  USING (
    EXISTS (
      SELECT 1 FROM public.bloodwork_entries be
       WHERE be.id = biomarker_results.bloodwork_entry_id
         AND be.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bloodwork_entries be
       WHERE be.id = biomarker_results.bloodwork_entry_id
         AND be.user_id = (SELECT auth.uid())
    )
  );

ALTER POLICY "Users can update own message read status" ON public.direct_messages
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
       WHERE c.id = direct_messages.conversation_id
         AND ((SELECT auth.uid()) IN (c.participant_one, c.participant_two))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.conversations c
       WHERE c.id = direct_messages.conversation_id
         AND ((SELECT auth.uid()) IN (c.participant_one, c.participant_two))
    )
  );

-- ---- Category C: role-based ownership ----------------------------------------

ALTER POLICY "Circle owners can update member roles" ON public.circle_members
  USING (
    EXISTS (
      SELECT 1 FROM public.circles
       WHERE circles.id = circle_members.circle_id
         AND circles.owner_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.circles
       WHERE circles.id = circle_members.circle_id
         AND circles.owner_id = (SELECT auth.uid())
    )
  );

COMMIT;
