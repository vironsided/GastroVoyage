-- =============================================================================
-- GastroVoyage — Canonical database schema (read-only reference)
--
-- The source of truth lives in `supabase/migrations/*.sql`. This file mirrors
-- those migrations for human reading and for tools that don't speak the
-- Supabase CLI. If you change anything, change the migrations first and then
-- regenerate this file (Phase 2 task: add a `pnpm db:doc` script).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Extensions
-- -----------------------------------------------------------------------------
create extension if not exists "pgcrypto";
create extension if not exists "citext";

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
-- set_updated_at()         -- trigger fn that bumps updated_at
-- is_admin()               -- reads JWT app_metadata.role = 'admin'
-- handle_new_user()        -- auto-creates profiles row when auth.users inserts

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
-- id           uuid PK references auth.users(id) on delete cascade
-- display_name text not null
-- avatar_url   text
-- home_city    text
-- bio          text
-- created_at   timestamptz default now()
-- updated_at   timestamptz default now()

-- -----------------------------------------------------------------------------
-- countries  (~195 rows, seeded)
-- -----------------------------------------------------------------------------
-- id            uuid PK
-- iso_a2        char(2) unique
-- iso_a3        char(3) unique
-- name          text
-- official_name text
-- region        text          -- "Asia", "Europe", "Africa", "Americas", "Oceania"
-- subregion     text
-- flag_emoji    text
-- centroid_lng  numeric(9,6)
-- centroid_lat  numeric(9,6)

-- -----------------------------------------------------------------------------
-- cuisines
-- -----------------------------------------------------------------------------
-- id             uuid PK
-- country_id     uuid -> countries(id) on delete cascade
-- name           text
-- description    text
-- signature_dish text
-- image_url      text

-- -----------------------------------------------------------------------------
-- restaurants
-- -----------------------------------------------------------------------------
-- id              uuid PK
-- name            text
-- country_id      uuid -> countries(id)
-- city            text
-- address         text
-- lng, lat        numeric(9,6)
-- cuisine_tags    text[]
-- is_partner      boolean default false
-- commission_rate numeric(5,2)            -- 0..100, nullable
-- partner_since   date
-- verified_at     timestamptz
-- phone, website  text
-- created_by      uuid -> auth.users(id) on delete set null

-- -----------------------------------------------------------------------------
-- visits  (the heart of the app)
-- -----------------------------------------------------------------------------
-- id            uuid PK
-- user_id       uuid -> auth.users(id) on delete cascade
-- country_id    uuid -> countries(id)
-- restaurant_id uuid -> restaurants(id) on delete set null  (nullable)
-- rating        smallint check 1..5
-- notes         text
-- visited_on    date default current_date
-- photo_path    text                                          -- storage path in instax-photos
-- UNIQUE (user_id, country_id)   -- one Instax per country per user

-- -----------------------------------------------------------------------------
-- check_ins  (B2B commission ledger)
-- -----------------------------------------------------------------------------
-- id             uuid PK
-- user_id        uuid -> auth.users(id) on delete cascade
-- restaurant_id  uuid -> restaurants(id) on delete cascade
-- visit_id       uuid -> visits(id) on delete set null
-- checked_in_at  timestamptz default now()
-- gps_lat, gps_lng numeric(9,6)
-- distance_m     integer        -- meters from restaurant pin
-- is_verified    boolean default false

-- -----------------------------------------------------------------------------
-- badges + user_badges  (achievements)
-- -----------------------------------------------------------------------------
-- badges       code PK, title, description, region?, threshold?, icon
-- user_badges  composite PK (user_id, badge_code)

-- -----------------------------------------------------------------------------
-- Storage buckets
-- -----------------------------------------------------------------------------
-- instax-photos      private   user-folder scoped
-- restaurant-images  public    admin write
-- map-exports        private   admin/service-role write, owner signed read

-- -----------------------------------------------------------------------------
-- RLS summary
-- -----------------------------------------------------------------------------
-- profiles, visits, check_ins, user_badges:  user_id = auth.uid()  OR  is_admin()
-- countries, cuisines, restaurants, badges:  public select, admin-only writes
-- check_ins updates/deletes:                  admin-only (preserve ledger)
-- instax-photos storage:                      user folder = auth.uid()
-- restaurant-images storage:                  public read, admin write
-- map-exports storage:                        user folder = auth.uid(), admin write

-- See supabase/migrations/*.sql for the exact DDL.
