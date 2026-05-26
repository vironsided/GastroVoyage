-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Tag your partner in a visit
--
-- When the user is in an active couple (migration 014), the visit logger
-- gets a "We were together" toggle. The flag is stored on the visit row so
-- shared bites can be filtered in the journal and counted in joint stats.
--
-- Nullable so legacy visits stay untouched (they read as "not tagged"); the
-- mobile defaults to false for new visits.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE visits ADD COLUMN IF NOT EXISTS with_partner BOOLEAN
  NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS visits_with_partner_idx
  ON visits (user_id, with_partner) WHERE with_partner = true;
