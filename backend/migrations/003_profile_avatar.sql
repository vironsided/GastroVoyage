-- Migration 003 — profile avatar URL
--
-- HOW TO RUN: paste this into the Supabase SQL editor and execute it once.
-- (There is no automated migration runner; the backend reads profiles with
--  select("*"), so until this runs the avatar feature simply has no data.)
--
-- Adds a nullable column holding the public URL of the user's avatar image,
-- uploaded through POST /uploads. Safe to run multiple times.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url text;
