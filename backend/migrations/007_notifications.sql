-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Notifications inbox
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the
-- notifications inbox feature will work.
--
-- This migration is re-runnable: every CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • notifications — one row per delivered alert to a user, with a typed
--     payload (jsonb) describing the originating event. Types include:
--       follow_request   — someone asked to follow me
--       follow_accepted  — my follow request was accepted
--       story_view       — someone watched my story (one row per (story, viewer))
--       journey_week     — I just completed another week of the couples' journey
--       badge_earned     — I just earned a new cuisine badge
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── notifications ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        NOT NULL,                      -- recipient
  actor_id   uuid,                                       -- who triggered (nullable for self-events)
  type       text        NOT NULL
                         CHECK (type IN (
                           'follow_request',
                           'follow_accepted',
                           'story_view',
                           'journey_week',
                           'badge_earned'
                         )),
  payload    jsonb       NOT NULL DEFAULT '{}'::jsonb,
  read       boolean     NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_user_read_idx
  ON notifications (user_id, read);

-- ── notifications RLS ────────────────────────────────────────────────────────
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- A user can only ever see their own notifications.
DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
CREATE POLICY "notifications_select_own" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Defence-in-depth insert policy: the API uses the service key (which bypasses
-- RLS) but a non-service caller may insert a row only when they are the actor
-- or the recipient. Service-role inserts skip this check entirely.
DROP POLICY IF EXISTS "notifications_insert_party" ON notifications;
CREATE POLICY "notifications_insert_party" ON notifications
  FOR INSERT WITH CHECK (
    auth.uid() = actor_id OR auth.uid() = user_id
  );

-- The recipient can mark their own notifications read / unread.
DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- The recipient can delete their own notifications.
DROP POLICY IF EXISTS "notifications_delete_own" ON notifications;
CREATE POLICY "notifications_delete_own" ON notifications
  FOR DELETE USING (auth.uid() = user_id);
