-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Couples (partner linking)
--
-- The couples_journey table from migration 005 only tracks weekly progress
-- per user. This migration adds an explicit "couple" relationship: two users
-- mutually agreeing to be partners. It enables tag-partner-in-visit, joint
-- stats, and partner-only UX (heart reactions, We Together card).
--
-- One row per couple. Status starts at 'pending' when the inviter sends the
-- invite; the invitee flips it to 'accepted'. A user can have at most one
-- active (pending OR accepted) couple at a time — enforced by partial unique
-- indexes below so an "ended" row never blocks a future relationship.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS couples (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- inviter
  partner_a_id uuid        NOT NULL,
  -- invitee
  partner_b_id uuid        NOT NULL,
  status       text        NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'accepted', 'ended')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  accepted_at  timestamptz,
  ended_at     timestamptz,
  CHECK (partner_a_id <> partner_b_id)
);

-- One active couple per side. The partial index lets historical 'ended' rows
-- co-exist with a brand new 'pending' or 'accepted' row.
CREATE UNIQUE INDEX IF NOT EXISTS couples_active_a_uidx
  ON couples (partner_a_id) WHERE status IN ('pending', 'accepted');
CREATE UNIQUE INDEX IF NOT EXISTS couples_active_b_uidx
  ON couples (partner_b_id) WHERE status IN ('pending', 'accepted');

CREATE INDEX IF NOT EXISTS couples_a_status_idx ON couples (partner_a_id, status);
CREATE INDEX IF NOT EXISTS couples_b_status_idx ON couples (partner_b_id, status);

-- RLS — service key bypasses, but defence in depth.
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "couples_select_own" ON couples;
CREATE POLICY "couples_select_own" ON couples
  FOR SELECT USING (auth.uid() = partner_a_id OR auth.uid() = partner_b_id);
