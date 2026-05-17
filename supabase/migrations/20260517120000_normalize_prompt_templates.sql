-- 20260517120000_normalize_prompt_templates.sql
--
-- Normalize the system_template column for the prompts that PR 3 of the AI Cost &
-- Architecture plan will switch to registry-as-truth (Mode A). The previous seed
-- (20260516120000_seed_prompt_template_bodies.sql) captured the raw text inside
-- Swift triple-quoted string literals, which includes leading source-code
-- indentation, a leading newline (the newline that follows the opening """),
-- trailing whitespace before the closing """, and Swift's own \<newline>
-- line-continuation escapes. The runtime string that iOS actually puts on the
-- wire is normalized by Swift before transmission, so to make the registry
-- byte-equal to the wire payload we must apply the same normalization here.
--
-- Swift's documented order for processing a multi-line string literal is:
--   1. drop the newline immediately following the opening """
--   2. dedent every interior line by the indentation of the closing """
--   3. process backslash escapes, including \<newline> line-continuations
--   4. drop the newline immediately preceding the closing """
--
-- We mirror that order. This migration is scoped to the five prompt_ids that
-- have a clean static call-site path (no caller-side composition or
-- string interpolation baked into the literal): lab_parse, nutrition_ai,
-- bloodwork_interp, journey_narrative, story_mode. The other prompt_ids
-- in prompt_templates are intentionally NOT touched here and will be
-- addressed by a follow-up PR that adds proper {{variable}} templating
-- and an iOS-side variable extraction layer.
--
-- After this migration, each of the five rows should be byte-equal to the
-- string that the corresponding iOS service places into the system role of
-- its OpenRouter request. That equality has been verified by md5 comparison
-- in a dry run against the production database.

BEGIN;

-- Step 1: strip the leading newline(s) introduced by the opening """ in the
-- Swift source.
UPDATE public.prompt_templates
SET system_template = regexp_replace(system_template, E'^\n+', '', '')
WHERE prompt_id IN ('lab_parse','nutrition_ai','bloodwork_interp','journey_narrative','story_mode')
  AND active = true;

-- Step 2: dedent each prompt by the minimum leading-whitespace indent across
-- its non-blank lines. This matches the Swift behavior where the closing """
-- defines the common indent that is stripped from every interior line.
WITH lines AS (
  SELECT pt.prompt_id,
         pt.version,
         l.ln,
         l.ord
  FROM public.prompt_templates pt,
       LATERAL regexp_split_to_table(pt.system_template, E'\n')
         WITH ORDINALITY AS l(ln, ord)
  WHERE pt.prompt_id IN ('lab_parse','nutrition_ai','bloodwork_interp','journey_narrative','story_mode')
    AND pt.active = true
),
mi AS (
  SELECT prompt_id,
         version,
         MIN(
           CASE WHEN ln ~ '\S'
                THEN length(ln) - length(regexp_replace(ln, '^[ \t]+', ''))
                ELSE NULL
           END
         ) AS n
  FROM lines
  GROUP BY prompt_id, version
),
dedented AS (
  SELECT l.prompt_id,
         l.version,
         string_agg(
           CASE WHEN l.ln ~ '\S' AND length(l.ln) >= mi.n
                THEN substring(l.ln from mi.n + 1)
                ELSE ''
           END,
           E'\n'
           ORDER BY l.ord
         ) AS new_template
  FROM lines l
  JOIN mi ON mi.prompt_id = l.prompt_id AND mi.version = l.version
  WHERE mi.n IS NOT NULL AND mi.n > 0
  GROUP BY l.prompt_id, l.version
)
UPDATE public.prompt_templates pt
SET system_template = d.new_template
FROM dedented d
WHERE pt.prompt_id = d.prompt_id
  AND pt.version = d.version;

-- Step 3: strip Swift's \<newline> line-continuations. After dedent, the
-- backslash-newline pair joins the two surrounding tokens with no
-- intervening whitespace, mirroring the runtime concatenation.
UPDATE public.prompt_templates
SET system_template = regexp_replace(system_template, E'\\\\\n', '', 'g')
WHERE prompt_id IN ('lab_parse','nutrition_ai','bloodwork_interp','journey_narrative','story_mode')
  AND active = true;

-- Step 4: trim trailing whitespace and the trailing newline that preceded
-- the closing """ in the Swift source.
UPDATE public.prompt_templates
SET system_template = regexp_replace(system_template, '\s+$', '')
WHERE prompt_id IN ('lab_parse','nutrition_ai','bloodwork_interp','journey_narrative','story_mode')
  AND active = true;

COMMIT;
