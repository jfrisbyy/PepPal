-- Performance indexes for hot tables.
--
-- Most reads from the iOS app hit (user_id, <time-or-status column>) tuples.
-- Without composite indexes, Postgres falls back to per-user table scans,
-- which gets noticeably slow once a single user has thousands of meals,
-- workouts, dose logs, or journey pins. These indexes are pure read-path
-- accelerators -- no schema changes, no data backfill needed.
--
-- Every CREATE INDEX uses IF NOT EXISTS so the migration is idempotent and
-- safe to re-run on environments that already shipped some of these.

BEGIN;

-- Activity logs ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS activity_logs_user_date_idx
  ON activity_logs (user_id, activity_date DESC);

-- Logged meals (huge table; daily window queries dominate) -----------------
CREATE INDEX IF NOT EXISTS logged_meals_user_logged_at_idx
  ON logged_meals (user_id, logged_at DESC);

-- Custom food items (per-user list, rarely huge but always filtered) ------
CREATE INDEX IF NOT EXISTS food_items_user_created_idx
  ON food_items (user_id, created_at DESC);

-- Workouts -----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS workouts_user_completed_idx
  ON workouts (user_id, completed_at DESC);

-- Training programs --------------------------------------------------------
CREATE INDEX IF NOT EXISTS training_programs_user_created_idx
  ON training_programs (user_id, created_at DESC);

-- Journey events (timeline) ------------------------------------------------
CREATE INDEX IF NOT EXISTS journey_events_user_ts_idx
  ON journey_events (user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS journey_events_user_lane_ts_idx
  ON journey_events (user_id, lane, timestamp DESC);

-- Basketball games ---------------------------------------------------------
CREATE INDEX IF NOT EXISTS basketball_games_user_played_idx
  ON basketball_games (user_id, played_at DESC);

-- Follows / followers (social graph) --------------------------------------
CREATE INDEX IF NOT EXISTS follows_follower_idx
  ON follows (follower_id);
CREATE INDEX IF NOT EXISTS follows_following_idx
  ON follows (following_id);

-- Follow requests (inbox / sent) ------------------------------------------
CREATE INDEX IF NOT EXISTS follow_requests_target_status_idx
  ON follow_requests (target_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS follow_requests_requester_status_idx
  ON follow_requests (requester_id, status);

-- Friend requests ----------------------------------------------------------
CREATE INDEX IF NOT EXISTS friend_requests_receiver_status_idx
  ON friend_requests (receiver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS friend_requests_sender_status_idx
  ON friend_requests (sender_id, status);

-- Direct messages (conversation feed) -------------------------------------
CREATE INDEX IF NOT EXISTS direct_messages_conv_created_idx
  ON direct_messages (conversation_id, created_at DESC);

-- Circle membership / discovery -------------------------------------------
CREATE INDEX IF NOT EXISTS circle_members_user_idx
  ON circle_members (user_id);
CREATE INDEX IF NOT EXISTS circle_members_circle_idx
  ON circle_members (circle_id);
CREATE INDEX IF NOT EXISTS circles_public_created_idx
  ON circles (is_private, created_at DESC);

-- Notifications inbox ------------------------------------------------------
CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON notifications (user_id, created_at DESC);

-- Posts (feed by author + global recent) ----------------------------------
CREATE INDEX IF NOT EXISTS posts_user_created_idx
  ON posts (user_id, created_at DESC);

COMMIT;
