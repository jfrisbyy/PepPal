-- PR 5 (Tier 2): user_context builder + signal emitter.
--
-- Adds public.rebuild_user_context(p_user_id, p_force), a pure-SQL aggregator
-- that pulls from existing tables (protocols/protocol_compounds, weight_logs,
-- manual_sleep_logs/health_sleep_nights, bloodwork_entries/bloodwork_flag,
-- logged_meals) and upserts a fresh row into user_context. It also diffs against
-- the prior row and appends user_signals for material deltas (new bloodwork
-- flags, weight trend sign flips, protocol/compound changes).
--
-- Zero LLM calls. Deterministic, idempotent.
--
-- Rate limit: if a fresh (non-expired) user_context row exists and p_force is
-- false, the builder short-circuits and returns the existing row unchanged.

BEGIN;

-- =========================================================================
-- Helper: weight summary (latest + 7-day delta)
-- =========================================================================
CREATE OR REPLACE FUNCTION public._uc_weight_summary(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  WITH recent AS (
    SELECT weight, unit, logged_at
      FROM public.weight_logs
     WHERE user_id = p_user_id
       AND logged_at >= now() - interval '30 days'
     ORDER BY logged_at DESC
     LIMIT 30
  ),
  latest AS (SELECT * FROM recent ORDER BY logged_at DESC LIMIT 1),
  week_ago AS (
    SELECT * FROM recent
     WHERE logged_at <= now() - interval '7 days'
     ORDER BY logged_at DESC LIMIT 1
  )
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'latest_weight', (SELECT weight FROM latest),
    'unit',          (SELECT unit FROM latest),
    'latest_at',     (SELECT logged_at FROM latest),
    'delta_7d',      (SELECT (l.weight - w.weight) FROM latest l, week_ago w),
    'samples_30d',   (SELECT count(*) FROM recent)
  ));
$fn$;

-- =========================================================================
-- Helper: sleep summary (manual_sleep_logs preferred, falls back to health_sleep_nights)
-- =========================================================================
CREATE OR REPLACE FUNCTION public._uc_sleep_summary(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  WITH manual AS (
    SELECT hours, quality, night
      FROM public.manual_sleep_logs
     WHERE user_id = p_user_id
       AND night >= (current_date - interval '7 days')
  ),
  apple AS (
    SELECT asleep_hours AS hours, night
      FROM public.health_sleep_nights
     WHERE user_id = p_user_id
       AND night >= (current_date - interval '7 days')
  ),
  unified AS (
    SELECT hours, night FROM manual
    UNION ALL
    SELECT hours, night FROM apple
     WHERE night NOT IN (SELECT night FROM manual)
  )
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'avg_hours_7d',     (SELECT round(avg(hours)::numeric, 2) FROM unified),
    'nights_logged_7d', (SELECT count(*) FROM unified),
    'avg_quality_7d',   (SELECT round(avg(quality)::numeric, 2) FROM manual WHERE quality IS NOT NULL)
  ));
$fn$;

-- =========================================================================
-- Helper: protocol summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public._uc_protocol_summary(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  WITH active AS (
    SELECT id, name, goal, start_date, total_weeks, is_open_ended
      FROM public.protocols
     WHERE user_id = p_user_id AND is_active = true
     ORDER BY start_date DESC NULLS LAST
     LIMIT 1
  ),
  compounds AS (
    SELECT jsonb_agg(jsonb_build_object(
             'compound', compound_name,
             'dose_mcg', dose_mcg,
             'frequency', frequency,
             'route', injection_route
           ) ORDER BY compound_name) AS arr
      FROM public.protocol_compounds
     WHERE protocol_id = (SELECT id FROM active)
  )
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'protocol_id',   (SELECT id FROM active),
    'name',          (SELECT name FROM active),
    'goal',          (SELECT goal FROM active),
    'start_date',    (SELECT start_date FROM active),
    'total_weeks',   (SELECT total_weeks FROM active),
    'is_open_ended', (SELECT is_open_ended FROM active),
    'cycle_week',    CASE WHEN (SELECT start_date FROM active) IS NOT NULL
                          THEN floor(extract(epoch FROM (now() - (SELECT start_date FROM active))) / 604800)::int + 1
                          ELSE NULL END,
    'compounds',     COALESCE((SELECT arr FROM compounds), '[]'::jsonb)
  ));
$fn$;

-- =========================================================================
-- Helper: bloodwork summary (last panel date + active flags)
-- =========================================================================
CREATE OR REPLACE FUNCTION public._uc_bloodwork_summary(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  WITH last_panel AS (
    SELECT id, date FROM public.bloodwork_entries
     WHERE user_id = p_user_id
     ORDER BY date DESC NULLS LAST LIMIT 1
  ),
  flags AS (
    SELECT jsonb_agg(jsonb_build_object(
             'biomarker', biomarker,
             'severity', severity,
             'trend', trend,
             'message', message,
             'related_compound', related_compound
           ) ORDER BY severity DESC NULLS LAST, biomarker) AS arr
      FROM public.bloodwork_flag
     WHERE user_id = p_user_id AND panel_id = (SELECT id FROM last_panel)
  )
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'last_panel_date', (SELECT date FROM last_panel),
    'last_panel_id',   (SELECT id FROM last_panel),
    'flags',           COALESCE((SELECT arr FROM flags), '[]'::jsonb)
  ));
$fn$;

-- =========================================================================
-- Helper: nutrition summary (7-day rolling averages)
-- =========================================================================
CREATE OR REPLACE FUNCTION public._uc_nutrition_summary(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  WITH week AS (
    SELECT date_trunc('day', logged_at) AS day,
           sum((calories * COALESCE(servings, 1))::numeric) AS kcal,
           sum(protein_g * COALESCE(servings, 1)) AS protein,
           sum(carbs_g   * COALESCE(servings, 1)) AS carbs,
           sum(fat_g     * COALESCE(servings, 1)) AS fat
      FROM public.logged_meals
     WHERE user_id = p_user_id AND logged_at >= now() - interval '7 days'
     GROUP BY 1
  )
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'days_logged_7d', (SELECT count(*) FROM week),
    'avg_calories',   (SELECT round(avg(kcal)::numeric, 0) FROM week),
    'avg_protein_g',  (SELECT round(avg(protein)::numeric, 1) FROM week),
    'avg_carbs_g',    (SELECT round(avg(carbs)::numeric, 1) FROM week),
    'avg_fat_g',      (SELECT round(avg(fat)::numeric, 1) FROM week)
  ));
$fn$;

-- =========================================================================
-- Main: rebuild_user_context
-- =========================================================================
CREATE OR REPLACE FUNCTION public.rebuild_user_context(
  p_user_id uuid,
  p_force   boolean DEFAULT false
)
RETURNS public.user_context
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  v_prev      public.user_context;
  v_new       public.user_context;
  v_protocol  jsonb;
  v_metrics   jsonb;
  v_bloodwork jsonb;
  v_nutrition jsonb;
  v_source    uuid;
  v_role      text;
BEGIN
  -- Authorization: privileged DB roles can rebuild any user; authenticated callers can only rebuild their own.
  v_role := current_user;
  IF v_role IN ('postgres', 'service_role', 'supabase_admin') THEN
    NULL;
  ELSIF v_role = 'authenticated' THEN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
      RAISE EXCEPTION 'rebuild_user_context: owner mismatch';
    END IF;
  ELSE
    RAISE EXCEPTION 'rebuild_user_context: role % not permitted', v_role;
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'rebuild_user_context: p_user_id is required';
  END IF;

  SELECT * INTO v_prev FROM public.user_context WHERE user_id = p_user_id;
  IF v_prev.user_id IS NOT NULL AND v_prev.expires_at > now() AND NOT p_force THEN
    RETURN v_prev;
  END IF;

  v_protocol  := public._uc_protocol_summary(p_user_id);
  v_metrics   := public._uc_weight_summary(p_user_id) || public._uc_sleep_summary(p_user_id);
  v_bloodwork := public._uc_bloodwork_summary(p_user_id);
  v_nutrition := public._uc_nutrition_summary(p_user_id);

  -- Watermark: id of the most recent ai_call_log row for this user
  SELECT id INTO v_source FROM public.ai_call_log
   WHERE user_id = p_user_id
   ORDER BY created_at DESC NULLS LAST
   LIMIT 1;

  INSERT INTO public.user_context AS uc (
    user_id, context_version, generated_at, source_event_id,
    protocol_summary, metrics_summary, bloodwork_summary, nutrition_summary, expires_at
  ) VALUES (
    p_user_id, 1, now(), v_source,
    COALESCE(v_protocol, '{}'::jsonb),
    COALESCE(v_metrics,  '{}'::jsonb),
    COALESCE(v_bloodwork,'{}'::jsonb),
    COALESCE(v_nutrition,'{}'::jsonb),
    now() + interval '24 hours'
  )
  ON CONFLICT (user_id) DO UPDATE
    SET generated_at      = EXCLUDED.generated_at,
        source_event_id   = EXCLUDED.source_event_id,
        protocol_summary  = EXCLUDED.protocol_summary,
        metrics_summary   = EXCLUDED.metrics_summary,
        bloodwork_summary = EXCLUDED.bloodwork_summary,
        nutrition_summary = EXCLUDED.nutrition_summary,
        expires_at        = EXCLUDED.expires_at
  RETURNING * INTO v_new;

  -- Emit user_signals for material deltas

  -- (1) New bloodwork flags (biomarker not in prev)
  IF (v_bloodwork ? 'flags') THEN
    INSERT INTO public.user_signals (user_id, signal_type, signal_source, payload, severity)
    SELECT
      p_user_id, 'bloodwork_flag', 'system',
      jsonb_build_object(
        'biomarker', f->>'biomarker',
        'severity',  f->>'severity',
        'trend',     f->>'trend',
        'related_compound', f->>'related_compound'
      ),
      CASE lower(COALESCE(f->>'severity',''))
        WHEN 'critical' THEN 5
        WHEN 'high'     THEN 4
        WHEN 'moderate' THEN 3
        WHEN 'low'      THEN 2
        ELSE 1
      END
    FROM jsonb_array_elements(v_bloodwork->'flags') f
    WHERE NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(v_prev.bloodwork_summary->'flags', '[]'::jsonb)) prev_f
       WHERE prev_f->>'biomarker' = f->>'biomarker'
    );
  END IF;

  -- (2) Weight trend sign flip (>0.25 unit magnitude)
  IF v_prev.user_id IS NOT NULL
     AND (v_prev.metrics_summary ? 'delta_7d')
     AND (v_metrics ? 'delta_7d') THEN
    DECLARE
      old_d numeric := (v_prev.metrics_summary->>'delta_7d')::numeric;
      new_d numeric := (v_metrics->>'delta_7d')::numeric;
    BEGIN
      IF sign(old_d) <> sign(new_d) AND abs(new_d) > 0.25 THEN
        INSERT INTO public.user_signals (user_id, signal_type, signal_source, payload, severity)
        VALUES (p_user_id, 'weight_trend_shift', 'system',
          jsonb_build_object('prev_delta_7d', old_d, 'new_delta_7d', new_d), 2);
      END IF;
    END;
  END IF;

  -- (3) Protocol change (compound list differs)
  IF v_prev.user_id IS NOT NULL
     AND (v_prev.protocol_summary->'compounds') IS DISTINCT FROM (v_protocol->'compounds') THEN
    INSERT INTO public.user_signals (user_id, signal_type, signal_source, payload, severity)
    VALUES (p_user_id, 'protocol_change', 'system',
      jsonb_build_object(
        'prev_compounds', COALESCE(v_prev.protocol_summary->'compounds', '[]'::jsonb),
        'new_compounds',  COALESCE(v_protocol->'compounds', '[]'::jsonb)
      ), 3);
  END IF;

  RETURN v_new;
END;
$fn$;

REVOKE ALL ON FUNCTION public.rebuild_user_context(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebuild_user_context(uuid, boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.rebuild_user_context(uuid, boolean) IS
'PR5: Pure-SQL aggregator. Rebuilds user_context from existing per-user data and appends user_signals for material deltas. Authenticated callers can rebuild only their own context; postgres/service_role/supabase_admin can rebuild any. Short-circuits when fresh (expires_at > now()) unless p_force=true.';

COMMIT;
