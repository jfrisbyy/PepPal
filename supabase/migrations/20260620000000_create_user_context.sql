-- PR 4 (Tier 2): Create user_context running brief + user_signals append-only event log.
--
-- This migration is schema-only. It introduces two tables that will support the
-- Tier 2 / Tier 3 "running context" pipeline:
--
--   public.user_context  : one row per user holding a versioned summary of
--                          protocol / metrics / bloodwork / nutrition state.
--                          Refreshed by a service-role builder (PR 5+).
--
--   public.user_signals  : append-only event log of meaningful signals (dose
--                          logged, weight-in, mood note, bloodwork flag,
--                          nutrition anomaly, etc.) that feed the rules engine
--                          in Tier 3.
--
-- NOTE: No builder, no consumer wiring, no recompute trigger in this migration.
-- All writes are gated behind SECURITY DEFINER RPCs callable only by the
-- service_role JWT. Clients can read their own rows (RLS) or call the read
-- RPCs; clients cannot write directly.
--
-- FK NOTE: ai_call_log.id is uuid (verified via information_schema). Both
-- user_context.source_event_id and user_signals.source_call_id are typed uuid.

BEGIN;

-- =========================================================================
-- Table: public.user_context
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.user_context (
  user_id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  context_version   integer NOT NULL DEFAULT 1,
  generated_at      timestamptz NOT NULL DEFAULT now(),
  source_event_id   uuid NULL,
  protocol_summary  jsonb NOT NULL DEFAULT '{}'::jsonb,
  metrics_summary   jsonb NOT NULL DEFAULT '{}'::jsonb,
  bloodwork_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  nutrition_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  expires_at        timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.user_context IS 'PR4: One row per user holding the current running context brief. Writes via service-role RPC only.';
COMMENT ON COLUMN public.user_context.context_version   IS 'Shape pointer; bump when the JSON layout of summary columns changes.';
COMMENT ON COLUMN public.user_context.source_event_id   IS 'Highest ai_call_log.id contributing to this brief; enables incremental recompute.';
COMMENT ON COLUMN public.user_context.protocol_summary  IS 'Active peptides, doses, cycle week.';
COMMENT ON COLUMN public.user_context.metrics_summary   IS 'Biomarker snapshot + trends (weight, sleep, mood, training load, etc.).';
COMMENT ON COLUMN public.user_context.bloodwork_summary IS 'Last lab panel snapshot, flagged out-of-range only.';
COMMENT ON COLUMN public.user_context.nutrition_summary IS '7-day rolling nutrition averages.';
COMMENT ON COLUMN public.user_context.expires_at        IS 'TTL; consumers should treat as stale past this point and trigger a rebuild.';

CREATE INDEX IF NOT EXISTS idx_user_context_expires_at
  ON public.user_context (expires_at);

CREATE INDEX IF NOT EXISTS idx_user_context_source_event
  ON public.user_context (source_event_id)
  WHERE source_event_id IS NOT NULL;

-- updated_at trigger
CREATE OR REPLACE FUNCTION public._user_context_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_user_context_touch_updated_at ON public.user_context;
CREATE TRIGGER trg_user_context_touch_updated_at
  BEFORE UPDATE ON public.user_context
  FOR EACH ROW EXECUTE FUNCTION public._user_context_touch_updated_at();

-- RLS: owner-only SELECT, no direct client writes.
ALTER TABLE public.user_context ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_context_owner_select ON public.user_context;
CREATE POLICY user_context_owner_select
  ON public.user_context
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- =========================================================================
-- Table: public.user_signals
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.user_signals (
  id              bigserial PRIMARY KEY,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  signal_type     text NOT NULL,
  signal_source   text NOT NULL,
  payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
  severity        smallint NULL,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  source_call_id  uuid NULL REFERENCES public.ai_call_log(id) ON DELETE SET NULL,
  CONSTRAINT user_signals_severity_range CHECK (severity IS NULL OR (severity BETWEEN 1 AND 5))
);

COMMENT ON TABLE  public.user_signals IS 'PR4: Append-only event log of user-level signals feeding the Tier 3 rules engine.';
COMMENT ON COLUMN public.user_signals.signal_type    IS 'e.g. dose_logged, weight_in, mood_note, bloodwork_flag, nutrition_anomaly.';
COMMENT ON COLUMN public.user_signals.signal_source  IS 'Origin: lab_parse | bloodwork_interp | nutrition_ai | journey_narrative | story_mode | user_input | system.';
COMMENT ON COLUMN public.user_signals.severity       IS 'Optional 1-5 priority hint.';
COMMENT ON COLUMN public.user_signals.occurred_at    IS 'When the underlying event happened (may pre-date created_at).';
COMMENT ON COLUMN public.user_signals.source_call_id IS 'ai_call_log row that produced this signal, when applicable.';

CREATE INDEX IF NOT EXISTS idx_user_signals_user_occurred
  ON public.user_signals (user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_signals_user_type_occurred
  ON public.user_signals (user_id, signal_type, occurred_at DESC);

-- RLS: owner-only SELECT, no direct client writes.
ALTER TABLE public.user_signals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_signals_owner_select ON public.user_signals;
CREATE POLICY user_signals_owner_select
  ON public.user_signals
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- =========================================================================
-- RPC: upsert_user_context (service-role only)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.upsert_user_context(
  p_user_id          uuid,
  p_protocol         jsonb DEFAULT '{}'::jsonb,
  p_metrics          jsonb DEFAULT '{}'::jsonb,
  p_bloodwork        jsonb DEFAULT '{}'::jsonb,
  p_nutrition        jsonb DEFAULT '{}'::jsonb,
  p_source_event_id  uuid DEFAULT NULL,
  p_ttl_seconds      integer DEFAULT 86400
)
RETURNS public.user_context
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_row public.user_context;
BEGIN
  IF current_setting('request.jwt.claim.role', true) IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'upsert_user_context: service_role required';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'upsert_user_context: p_user_id is required';
  END IF;

  INSERT INTO public.user_context AS uc (
    user_id, context_version, generated_at, source_event_id,
    protocol_summary, metrics_summary, bloodwork_summary, nutrition_summary,
    expires_at
  )
  VALUES (
    p_user_id, 1, now(), p_source_event_id,
    COALESCE(p_protocol,  '{}'::jsonb),
    COALESCE(p_metrics,   '{}'::jsonb),
    COALESCE(p_bloodwork, '{}'::jsonb),
    COALESCE(p_nutrition, '{}'::jsonb),
    now() + make_interval(secs => GREATEST(p_ttl_seconds, 60))
  )
  ON CONFLICT (user_id) DO UPDATE
    SET generated_at      = EXCLUDED.generated_at,
        source_event_id   = EXCLUDED.source_event_id,
        protocol_summary  = EXCLUDED.protocol_summary,
        metrics_summary   = EXCLUDED.metrics_summary,
        bloodwork_summary = EXCLUDED.bloodwork_summary,
        nutrition_summary = EXCLUDED.nutrition_summary,
        expires_at        = EXCLUDED.expires_at
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$fn$;

REVOKE ALL ON FUNCTION public.upsert_user_context(uuid, jsonb, jsonb, jsonb, jsonb, uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_user_context(uuid, jsonb, jsonb, jsonb, jsonb, uuid, integer) TO service_role;

-- =========================================================================
-- RPC: get_user_context (owner-readable via RLS)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.get_user_context(p_user_id uuid)
RETURNS public.user_context
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $fn$
  SELECT *
    FROM public.user_context
   WHERE user_id = p_user_id
$fn$;

REVOKE ALL ON FUNCTION public.get_user_context(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_context(uuid) TO authenticated, service_role;

-- =========================================================================
-- RPC: append_user_signal (service-role only)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.append_user_signal(
  p_user_id        uuid,
  p_signal_type    text,
  p_signal_source  text,
  p_payload        jsonb DEFAULT '{}'::jsonb,
  p_severity       smallint DEFAULT NULL,
  p_occurred_at    timestamptz DEFAULT NULL,
  p_source_call_id uuid DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_id bigint;
BEGIN
  IF current_setting('request.jwt.claim.role', true) IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'append_user_signal: service_role required';
  END IF;

  IF p_user_id IS NULL OR p_signal_type IS NULL OR p_signal_source IS NULL THEN
    RAISE EXCEPTION 'append_user_signal: user_id, signal_type, signal_source are required';
  END IF;

  INSERT INTO public.user_signals (
    user_id, signal_type, signal_source, payload, severity, occurred_at, source_call_id
  )
  VALUES (
    p_user_id,
    p_signal_type,
    p_signal_source,
    COALESCE(p_payload, '{}'::jsonb),
    p_severity,
    COALESCE(p_occurred_at, now()),
    p_source_call_id
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public.append_user_signal(uuid, text, text, jsonb, smallint, timestamptz, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.append_user_signal(uuid, text, text, jsonb, smallint, timestamptz, uuid) TO service_role;

-- =========================================================================
-- RPC: get_recent_user_signals (owner-readable via RLS)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.get_recent_user_signals(
  p_user_id uuid,
  p_limit   integer DEFAULT 50,
  p_since   timestamptz DEFAULT NULL
)
RETURNS SETOF public.user_signals
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $fn$
  SELECT *
    FROM public.user_signals
   WHERE user_id = p_user_id
     AND (p_since IS NULL OR occurred_at >= p_since)
   ORDER BY occurred_at DESC
   LIMIT GREATEST(LEAST(p_limit, 500), 1)
$fn$;

REVOKE ALL ON FUNCTION public.get_recent_user_signals(uuid, integer, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recent_user_signals(uuid, integer, timestamptz) TO authenticated, service_role;

COMMIT;
