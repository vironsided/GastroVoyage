-- =============================================================================
-- GastroVoyage — One-shot DEV installer
-- Concatenation of all migrations + dev seed. Paste this into Supabase SQL Editor.
-- Idempotent for re-runs of seed-dev; the schema/RLS/countries portion is NOT.
-- =============================================================================



-- ===== source: supabase\migrations\20260514000000_init_schema.sql =====

-- =============================================================================
-- GastroVoyage — Initial schema
-- Phase 1
-- =============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "citext";

-- -----------------------------------------------------------------------------
-- Helper: updated_at trigger
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Helper: is_admin() — used by RLS policies in 20260514000100
-- -----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin',
    false
  );
$$;

-- -----------------------------------------------------------------------------
-- profiles  (1:1 with auth.users)
-- -----------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url   text,
  home_city    text,
  bio          text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create profile row when auth.users gets a row
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- countries  (master list, ~195 rows from seed)
-- -----------------------------------------------------------------------------
create table public.countries (
  id            uuid primary key default gen_random_uuid(),
  iso_a2        char(2) not null unique,
  iso_a3        char(3) not null unique,
  name          text not null,
  official_name text,
  region        text not null,     -- e.g. "Asia", "Europe"
  subregion     text,              -- e.g. "Western Asia"
  flag_emoji    text not null,
  centroid_lng  numeric(9, 6) not null,
  centroid_lat  numeric(9, 6) not null,
  created_at    timestamptz not null default now()
);

create index countries_region_idx on public.countries (region);
create index countries_subregion_idx on public.countries (subregion);

-- -----------------------------------------------------------------------------
-- cuisines  (signature cuisine info per country; can be many per country)
-- -----------------------------------------------------------------------------
create table public.cuisines (
  id             uuid primary key default gen_random_uuid(),
  country_id     uuid not null references public.countries(id) on delete cascade,
  name           text not null,
  description    text,
  signature_dish text,
  image_url      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index cuisines_country_idx on public.cuisines (country_id);

create trigger cuisines_updated_at
  before update on public.cuisines
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- restaurants
-- -----------------------------------------------------------------------------
create table public.restaurants (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  country_id      uuid not null references public.countries(id),  -- cuisine country
  city            text not null,
  address         text,
  lng             numeric(9, 6),
  lat             numeric(9, 6),
  cuisine_tags    text[] not null default '{}',
  is_partner      boolean not null default false,
  commission_rate numeric(5, 2) check (commission_rate is null or (commission_rate >= 0 and commission_rate <= 100)),
  partner_since   date,
  verified_at     timestamptz,
  phone           text,
  website         text,
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index restaurants_country_idx on public.restaurants (country_id);
create index restaurants_city_idx on public.restaurants (city);
create index restaurants_partner_idx on public.restaurants (is_partner) where is_partner = true;

create trigger restaurants_updated_at
  before update on public.restaurants
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- visits  (a user's Instax for a country — one per country per user)
-- -----------------------------------------------------------------------------
create table public.visits (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  country_id    uuid not null references public.countries(id),
  restaurant_id uuid references public.restaurants(id) on delete set null,
  rating        smallint check (rating between 1 and 5),
  notes         text,
  visited_on    date not null default current_date,
  photo_path    text,             -- storage path: instax-photos/{user_id}/{country_iso}/{uuid}.jpg
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, country_id)
);

create index visits_user_idx on public.visits (user_id);
create index visits_country_idx on public.visits (country_id);
create index visits_visited_on_idx on public.visits (visited_on);

create trigger visits_updated_at
  before update on public.visits
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- check_ins  (GPS check-ins at partner restaurants — B2B commission ledger)
-- -----------------------------------------------------------------------------
create table public.check_ins (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  visit_id       uuid references public.visits(id) on delete set null,
  checked_in_at  timestamptz not null default now(),
  gps_lat        numeric(9, 6),
  gps_lng        numeric(9, 6),
  distance_m     integer,           -- meters from the restaurant's pin at check-in time
  is_verified    boolean not null default false   -- set by server-side validation
);

create index check_ins_user_idx on public.check_ins (user_id);
create index check_ins_restaurant_idx on public.check_ins (restaurant_id);
create index check_ins_checked_in_at_idx on public.check_ins (checked_in_at);

-- -----------------------------------------------------------------------------
-- badges  (catalog of achievements)
-- -----------------------------------------------------------------------------
create table public.badges (
  code         text primary key,
  title        text not null,
  description  text not null,
  region       text,                -- nullable: region-tied badges
  threshold    integer,             -- nullable: e.g. "10 visits"
  icon         text,                -- emoji or icon key
  sort_order   integer not null default 0
);

create table public.user_badges (
  user_id     uuid not null references auth.users(id) on delete cascade,
  badge_code  text not null references public.badges(code) on delete cascade,
  earned_at   timestamptz not null default now(),
  primary key (user_id, badge_code)
);

create index user_badges_user_idx on public.user_badges (user_id);

-- Seed canonical badges
insert into public.badges (code, title, description, region, threshold, icon, sort_order) values
  ('first_steps',       'First Steps',          'Logged your first cuisine.',                    null, 1,   'sparkles',     1),
  ('asian_explorer',    'Asian Explorer',       'Tried 10 cuisines from Asia.',                  'Asia', 10, 'lantern',      10),
  ('european_voyager',  'European Voyager',     'Tried 10 cuisines from Europe.',                'Europe', 10, 'castle',     11),
  ('african_pioneer',   'African Pioneer',      'Tried 10 cuisines from Africa.',                'Africa', 10, 'baobab',     12),
  ('american_trailblazer', 'Americas Trailblazer', 'Tried 10 cuisines from the Americas.',       'Americas', 10, 'compass',  13),
  ('oceania_sailor',    'Oceania Sailor',       'Tried 5 cuisines from Oceania.',                'Oceania', 5,  'wave',       14),
  ('mediterranean_master', 'Mediterranean Master', 'Completed all Mediterranean cuisines.',      'Mediterranean', null, 'olive', 20),
  ('half_world',        'Halfway Around',       'Logged 100 cuisines.',                          null, 100, 'globe',        50),
  ('world_traveler',    'World Traveler',       'Completed all 195 cuisines.',                   null, 195, 'crown',        99);

-- -----------------------------------------------------------------------------
-- Storage buckets
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('instax-photos',     'instax-photos',     false),
  ('restaurant-images', 'restaurant-images', true),
  ('map-exports',       'map-exports',       false)
on conflict (id) do nothing;


-- ===== source: supabase\migrations\20260514000100_rls_policies.sql =====

-- =============================================================================
-- GastroVoyage — Row Level Security
-- =============================================================================

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles: read own or admin"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

create policy "profiles: insert own"
  on public.profiles for insert
  with check (id = auth.uid());

create policy "profiles: update own or admin"
  on public.profiles for update
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy "profiles: delete admin only"
  on public.profiles for delete
  using (public.is_admin());

-- -----------------------------------------------------------------------------
-- countries  (public read, admin write)
-- -----------------------------------------------------------------------------
alter table public.countries enable row level security;

create policy "countries: anyone can read"
  on public.countries for select
  using (true);

create policy "countries: admin write"
  on public.countries for insert with check (public.is_admin());
create policy "countries: admin update"
  on public.countries for update using (public.is_admin()) with check (public.is_admin());
create policy "countries: admin delete"
  on public.countries for delete using (public.is_admin());

-- -----------------------------------------------------------------------------
-- cuisines  (public read, admin write)
-- -----------------------------------------------------------------------------
alter table public.cuisines enable row level security;

create policy "cuisines: anyone can read"
  on public.cuisines for select using (true);
create policy "cuisines: admin insert"
  on public.cuisines for insert with check (public.is_admin());
create policy "cuisines: admin update"
  on public.cuisines for update using (public.is_admin()) with check (public.is_admin());
create policy "cuisines: admin delete"
  on public.cuisines for delete using (public.is_admin());

-- -----------------------------------------------------------------------------
-- restaurants  (public read, admin write)
-- -----------------------------------------------------------------------------
alter table public.restaurants enable row level security;

create policy "restaurants: anyone can read"
  on public.restaurants for select using (true);
create policy "restaurants: admin insert"
  on public.restaurants for insert with check (public.is_admin());
create policy "restaurants: admin update"
  on public.restaurants for update using (public.is_admin()) with check (public.is_admin());
create policy "restaurants: admin delete"
  on public.restaurants for delete using (public.is_admin());

-- -----------------------------------------------------------------------------
-- visits  (owner only)
-- -----------------------------------------------------------------------------
alter table public.visits enable row level security;

create policy "visits: read own or admin"
  on public.visits for select using (user_id = auth.uid() or public.is_admin());
create policy "visits: insert own"
  on public.visits for insert with check (user_id = auth.uid());
create policy "visits: update own"
  on public.visits for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "visits: delete own or admin"
  on public.visits for delete using (user_id = auth.uid() or public.is_admin());

-- -----------------------------------------------------------------------------
-- check_ins  (owner read/insert, admin read all)
-- -----------------------------------------------------------------------------
alter table public.check_ins enable row level security;

create policy "check_ins: read own or admin"
  on public.check_ins for select using (user_id = auth.uid() or public.is_admin());
create policy "check_ins: insert own"
  on public.check_ins for insert with check (user_id = auth.uid());
-- Updates/deletes are admin-only — users shouldn't be able to revise the commission ledger.
create policy "check_ins: admin update"
  on public.check_ins for update using (public.is_admin()) with check (public.is_admin());
create policy "check_ins: admin delete"
  on public.check_ins for delete using (public.is_admin());

-- -----------------------------------------------------------------------------
-- badges  (public read, admin write)
-- -----------------------------------------------------------------------------
alter table public.badges enable row level security;

create policy "badges: anyone can read"
  on public.badges for select using (true);
create policy "badges: admin insert"
  on public.badges for insert with check (public.is_admin());
create policy "badges: admin update"
  on public.badges for update using (public.is_admin()) with check (public.is_admin());
create policy "badges: admin delete"
  on public.badges for delete using (public.is_admin());

-- -----------------------------------------------------------------------------
-- user_badges  (owner read, system inserts)
-- -----------------------------------------------------------------------------
alter table public.user_badges enable row level security;

create policy "user_badges: read own or admin"
  on public.user_badges for select using (user_id = auth.uid() or public.is_admin());
-- Awarding is done server-side; restrict to admin/service-role for now.
create policy "user_badges: admin insert"
  on public.user_badges for insert with check (public.is_admin());
create policy "user_badges: admin delete"
  on public.user_badges for delete using (public.is_admin());

-- -----------------------------------------------------------------------------
-- Storage policies
-- -----------------------------------------------------------------------------

-- instax-photos: users can read/write only their own folder (path starts with their uid).
create policy "instax-photos: read own"
  on storage.objects for select
  using (
    bucket_id = 'instax-photos'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin())
  );

create policy "instax-photos: insert own"
  on storage.objects for insert
  with check (
    bucket_id = 'instax-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "instax-photos: update own"
  on storage.objects for update
  using (
    bucket_id = 'instax-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "instax-photos: delete own"
  on storage.objects for delete
  using (
    bucket_id = 'instax-photos'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin())
  );

-- restaurant-images: public read, admin write.
create policy "restaurant-images: public read"
  on storage.objects for select
  using (bucket_id = 'restaurant-images');

create policy "restaurant-images: admin write"
  on storage.objects for insert
  with check (bucket_id = 'restaurant-images' and public.is_admin());

create policy "restaurant-images: admin update"
  on storage.objects for update
  using (bucket_id = 'restaurant-images' and public.is_admin());

create policy "restaurant-images: admin delete"
  on storage.objects for delete
  using (bucket_id = 'restaurant-images' and public.is_admin());

-- map-exports: owner read (via signed URL), admin/service-role write.
create policy "map-exports: read own"
  on storage.objects for select
  using (
    bucket_id = 'map-exports'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin())
  );

create policy "map-exports: admin write"
  on storage.objects for insert
  with check (bucket_id = 'map-exports' and public.is_admin());


-- ===== source: supabase\migrations\20260514000200_seed_countries.sql =====

-- =============================================================================
-- GastroVoyage — Seed: countries
-- Generated by tools/generate-countries.mjs from the world-countries npm package.
-- Do not edit by hand — re-run the generator if data changes.
-- Source rows: 194
-- =============================================================================

insert into public.countries (iso_a2, iso_a3, name, official_name, region, subregion, flag_emoji, centroid_lng, centroid_lat) values
  ('AF', 'AFG', 'Afghanistan', 'Islamic Republic of Afghanistan', 'Asia', 'Southern Asia', '🇦🇫', 65, 33),
  ('AL', 'ALB', 'Albania', 'Republic of Albania', 'Europe', 'Southeast Europe', '🇦🇱', 20, 41),
  ('DZ', 'DZA', 'Algeria', 'People''s Democratic Republic of Algeria', 'Africa', 'Northern Africa', '🇩🇿', 3, 28),
  ('AD', 'AND', 'Andorra', 'Principality of Andorra', 'Europe', 'Southern Europe', '🇦🇩', 1.5, 42.5),
  ('AO', 'AGO', 'Angola', 'Republic of Angola', 'Africa', 'Middle Africa', '🇦🇴', 18.5, -12.5),
  ('AG', 'ATG', 'Antigua and Barbuda', 'Antigua and Barbuda', 'Americas', 'Caribbean', '🇦🇬', -61.8, 17.05),
  ('AR', 'ARG', 'Argentina', 'Argentine Republic', 'Americas', 'South America', '🇦🇷', -64, -34),
  ('AM', 'ARM', 'Armenia', 'Republic of Armenia', 'Asia', 'Western Asia', '🇦🇲', 45, 40),
  ('AU', 'AUS', 'Australia', 'Commonwealth of Australia', 'Oceania', 'Australia and New Zealand', '🇦🇺', 133, -27),
  ('AT', 'AUT', 'Austria', 'Republic of Austria', 'Europe', 'Central Europe', '🇦🇹', 13.33333333, 47.33333333),
  ('AZ', 'AZE', 'Azerbaijan', 'Republic of Azerbaijan', 'Asia', 'Western Asia', '🇦🇿', 47.5, 40.5),
  ('BS', 'BHS', 'Bahamas', 'Commonwealth of the Bahamas', 'Americas', 'Caribbean', '🇧🇸', -76, 24.25),
  ('BH', 'BHR', 'Bahrain', 'Kingdom of Bahrain', 'Asia', 'Western Asia', '🇧🇭', 50.55, 26),
  ('BD', 'BGD', 'Bangladesh', 'People''s Republic of Bangladesh', 'Asia', 'Southern Asia', '🇧🇩', 90, 24),
  ('BB', 'BRB', 'Barbados', 'Barbados', 'Americas', 'Caribbean', '🇧🇧', -59.53333333, 13.16666666),
  ('BY', 'BLR', 'Belarus', 'Republic of Belarus', 'Europe', 'Eastern Europe', '🇧🇾', 28, 53),
  ('BE', 'BEL', 'Belgium', 'Kingdom of Belgium', 'Europe', 'Western Europe', '🇧🇪', 4, 50.83333333),
  ('BZ', 'BLZ', 'Belize', 'Belize', 'Americas', 'Central America', '🇧🇿', -88.75, 17.25),
  ('BJ', 'BEN', 'Benin', 'Republic of Benin', 'Africa', 'Western Africa', '🇧🇯', 2.25, 9.5),
  ('BT', 'BTN', 'Bhutan', 'Kingdom of Bhutan', 'Asia', 'Southern Asia', '🇧🇹', 90.5, 27.5),
  ('BO', 'BOL', 'Bolivia', 'Plurinational State of Bolivia', 'Americas', 'South America', '🇧🇴', -65, -17),
  ('BA', 'BIH', 'Bosnia and Herzegovina', 'Bosnia and Herzegovina', 'Europe', 'Southeast Europe', '🇧🇦', 18, 44),
  ('BW', 'BWA', 'Botswana', 'Republic of Botswana', 'Africa', 'Southern Africa', '🇧🇼', 24, -22),
  ('BR', 'BRA', 'Brazil', 'Federative Republic of Brazil', 'Americas', 'South America', '🇧🇷', -55, -10),
  ('BN', 'BRN', 'Brunei', 'Nation of Brunei, Abode of Peace', 'Asia', 'South-Eastern Asia', '🇧🇳', 114.66666666, 4.5),
  ('BG', 'BGR', 'Bulgaria', 'Republic of Bulgaria', 'Europe', 'Southeast Europe', '🇧🇬', 25, 43),
  ('BF', 'BFA', 'Burkina Faso', 'Burkina Faso', 'Africa', 'Western Africa', '🇧🇫', -2, 13),
  ('BI', 'BDI', 'Burundi', 'Republic of Burundi', 'Africa', 'Eastern Africa', '🇧🇮', 30, -3.5),
  ('KH', 'KHM', 'Cambodia', 'Kingdom of Cambodia', 'Asia', 'South-Eastern Asia', '🇰🇭', 105, 13),
  ('CM', 'CMR', 'Cameroon', 'Republic of Cameroon', 'Africa', 'Middle Africa', '🇨🇲', 12, 6),
  ('CA', 'CAN', 'Canada', 'Canada', 'Americas', 'North America', '🇨🇦', -95, 60),
  ('CV', 'CPV', 'Cape Verde', 'Republic of Cabo Verde', 'Africa', 'Western Africa', '🇨🇻', -24, 16),
  ('CF', 'CAF', 'Central African Republic', 'Central African Republic', 'Africa', 'Middle Africa', '🇨🇫', 21, 7),
  ('TD', 'TCD', 'Chad', 'Republic of Chad', 'Africa', 'Middle Africa', '🇹🇩', 19, 15),
  ('CL', 'CHL', 'Chile', 'Republic of Chile', 'Americas', 'South America', '🇨🇱', -71, -30),
  ('CN', 'CHN', 'China', 'People''s Republic of China', 'Asia', 'Eastern Asia', '🇨🇳', 105, 35),
  ('CO', 'COL', 'Colombia', 'Republic of Colombia', 'Americas', 'South America', '🇨🇴', -72, 4),
  ('KM', 'COM', 'Comoros', 'Union of the Comoros', 'Africa', 'Eastern Africa', '🇰🇲', 44.25, -12.16666666),
  ('CR', 'CRI', 'Costa Rica', 'Republic of Costa Rica', 'Americas', 'Central America', '🇨🇷', -84, 10),
  ('HR', 'HRV', 'Croatia', 'Republic of Croatia', 'Europe', 'Southeast Europe', '🇭🇷', 15.5, 45.16666666),
  ('CU', 'CUB', 'Cuba', 'Republic of Cuba', 'Americas', 'Caribbean', '🇨🇺', -80, 21.5),
  ('CY', 'CYP', 'Cyprus', 'Republic of Cyprus', 'Europe', 'Southern Europe', '🇨🇾', 33, 35),
  ('CZ', 'CZE', 'Czechia', 'Czech Republic', 'Europe', 'Central Europe', '🇨🇿', 15.5, 49.75),
  ('DK', 'DNK', 'Denmark', 'Kingdom of Denmark', 'Europe', 'Northern Europe', '🇩🇰', 10, 56),
  ('DJ', 'DJI', 'Djibouti', 'Republic of Djibouti', 'Africa', 'Eastern Africa', '🇩🇯', 43, 11.5),
  ('DM', 'DMA', 'Dominica', 'Commonwealth of Dominica', 'Americas', 'Caribbean', '🇩🇲', -61.33333333, 15.41666666),
  ('DO', 'DOM', 'Dominican Republic', 'Dominican Republic', 'Americas', 'Caribbean', '🇩🇴', -70.66666666, 19),
  ('CD', 'COD', 'DR Congo', 'Democratic Republic of the Congo', 'Africa', 'Middle Africa', '🇨🇩', 25, 0),
  ('EC', 'ECU', 'Ecuador', 'Republic of Ecuador', 'Americas', 'South America', '🇪🇨', -77.5, -2),
  ('EG', 'EGY', 'Egypt', 'Arab Republic of Egypt', 'Africa', 'Northern Africa', '🇪🇬', 30, 27),
  ('SV', 'SLV', 'El Salvador', 'Republic of El Salvador', 'Americas', 'Central America', '🇸🇻', -88.91666666, 13.83333333),
  ('GQ', 'GNQ', 'Equatorial Guinea', 'Republic of Equatorial Guinea', 'Africa', 'Middle Africa', '🇬🇶', 10, 2),
  ('ER', 'ERI', 'Eritrea', 'State of Eritrea', 'Africa', 'Eastern Africa', '🇪🇷', 39, 15),
  ('EE', 'EST', 'Estonia', 'Republic of Estonia', 'Europe', 'Northern Europe', '🇪🇪', 26, 59),
  ('SZ', 'SWZ', 'Eswatini', 'Kingdom of Eswatini', 'Africa', 'Southern Africa', '🇸🇿', 31.5, -26.5),
  ('ET', 'ETH', 'Ethiopia', 'Federal Democratic Republic of Ethiopia', 'Africa', 'Eastern Africa', '🇪🇹', 38, 8),
  ('FJ', 'FJI', 'Fiji', 'Republic of Fiji', 'Oceania', 'Melanesia', '🇫🇯', 175, -18),
  ('FI', 'FIN', 'Finland', 'Republic of Finland', 'Europe', 'Northern Europe', '🇫🇮', 26, 64),
  ('FR', 'FRA', 'France', 'French Republic', 'Europe', 'Western Europe', '🇫🇷', 2, 46),
  ('GA', 'GAB', 'Gabon', 'Gabonese Republic', 'Africa', 'Middle Africa', '🇬🇦', 11.75, -1),
  ('GM', 'GMB', 'Gambia', 'Republic of the Gambia', 'Africa', 'Western Africa', '🇬🇲', -16.56666666, 13.46666666),
  ('GE', 'GEO', 'Georgia', 'Georgia', 'Asia', 'Western Asia', '🇬🇪', 43.5, 42),
  ('DE', 'DEU', 'Germany', 'Federal Republic of Germany', 'Europe', 'Western Europe', '🇩🇪', 9, 51),
  ('GH', 'GHA', 'Ghana', 'Republic of Ghana', 'Africa', 'Western Africa', '🇬🇭', -2, 8),
  ('GR', 'GRC', 'Greece', 'Hellenic Republic', 'Europe', 'Southern Europe', '🇬🇷', 22, 39),
  ('GD', 'GRD', 'Grenada', 'Grenada', 'Americas', 'Caribbean', '🇬🇩', -61.66666666, 12.11666666),
  ('GT', 'GTM', 'Guatemala', 'Republic of Guatemala', 'Americas', 'Central America', '🇬🇹', -90.25, 15.5),
  ('GN', 'GIN', 'Guinea', 'Republic of Guinea', 'Africa', 'Western Africa', '🇬🇳', -10, 11),
  ('GW', 'GNB', 'Guinea-Bissau', 'Republic of Guinea-Bissau', 'Africa', 'Western Africa', '🇬🇼', -15, 12),
  ('GY', 'GUY', 'Guyana', 'Co-operative Republic of Guyana', 'Americas', 'South America', '🇬🇾', -59, 5),
  ('HT', 'HTI', 'Haiti', 'Republic of Haiti', 'Americas', 'Caribbean', '🇭🇹', -72.41666666, 19),
  ('HN', 'HND', 'Honduras', 'Republic of Honduras', 'Americas', 'Central America', '🇭🇳', -86.5, 15),
  ('HU', 'HUN', 'Hungary', 'Hungary', 'Europe', 'Central Europe', '🇭🇺', 20, 47),
  ('IS', 'ISL', 'Iceland', 'Iceland', 'Europe', 'Northern Europe', '🇮🇸', -18, 65),
  ('IN', 'IND', 'India', 'Republic of India', 'Asia', 'Southern Asia', '🇮🇳', 77, 20),
  ('ID', 'IDN', 'Indonesia', 'Republic of Indonesia', 'Asia', 'South-Eastern Asia', '🇮🇩', 120, -5),
  ('IR', 'IRN', 'Iran', 'Islamic Republic of Iran', 'Asia', 'Southern Asia', '🇮🇷', 53, 32),
  ('IQ', 'IRQ', 'Iraq', 'Republic of Iraq', 'Asia', 'Western Asia', '🇮🇶', 44, 33),
  ('IE', 'IRL', 'Ireland', 'Republic of Ireland', 'Europe', 'Northern Europe', '🇮🇪', -8, 53),
  ('IL', 'ISR', 'Israel', 'State of Israel', 'Asia', 'Western Asia', '🇮🇱', 35.13, 31.47),
  ('IT', 'ITA', 'Italy', 'Italian Republic', 'Europe', 'Southern Europe', '🇮🇹', 12.83333333, 42.83333333),
  ('CI', 'CIV', 'Ivory Coast', 'Republic of Côte d''Ivoire', 'Africa', 'Western Africa', '🇨🇮', -5, 8),
  ('JM', 'JAM', 'Jamaica', 'Jamaica', 'Americas', 'Caribbean', '🇯🇲', -77.5, 18.25),
  ('JP', 'JPN', 'Japan', 'Japan', 'Asia', 'Eastern Asia', '🇯🇵', 138, 36),
  ('JO', 'JOR', 'Jordan', 'Hashemite Kingdom of Jordan', 'Asia', 'Western Asia', '🇯🇴', 36, 31),
  ('KZ', 'KAZ', 'Kazakhstan', 'Republic of Kazakhstan', 'Asia', 'Central Asia', '🇰🇿', 68, 48),
  ('KE', 'KEN', 'Kenya', 'Republic of Kenya', 'Africa', 'Eastern Africa', '🇰🇪', 38, 1),
  ('KI', 'KIR', 'Kiribati', 'Independent and Sovereign Republic of Kiribati', 'Oceania', 'Micronesia', '🇰🇮', 173, 1.41666666),
  ('KW', 'KWT', 'Kuwait', 'State of Kuwait', 'Asia', 'Western Asia', '🇰🇼', 45.75, 29.5),
  ('KG', 'KGZ', 'Kyrgyzstan', 'Kyrgyz Republic', 'Asia', 'Central Asia', '🇰🇬', 75, 41),
  ('LA', 'LAO', 'Laos', 'Lao People''s Democratic Republic', 'Asia', 'South-Eastern Asia', '🇱🇦', 105, 18),
  ('LV', 'LVA', 'Latvia', 'Republic of Latvia', 'Europe', 'Northern Europe', '🇱🇻', 25, 57),
  ('LB', 'LBN', 'Lebanon', 'Lebanese Republic', 'Asia', 'Western Asia', '🇱🇧', 35.83333333, 33.83333333),
  ('LS', 'LSO', 'Lesotho', 'Kingdom of Lesotho', 'Africa', 'Southern Africa', '🇱🇸', 28.5, -29.5),
  ('LR', 'LBR', 'Liberia', 'Republic of Liberia', 'Africa', 'Western Africa', '🇱🇷', -9.5, 6.5),
  ('LY', 'LBY', 'Libya', 'State of Libya', 'Africa', 'Northern Africa', '🇱🇾', 17, 25),
  ('LI', 'LIE', 'Liechtenstein', 'Principality of Liechtenstein', 'Europe', 'Western Europe', '🇱🇮', 9.53333333, 47.26666666),
  ('LT', 'LTU', 'Lithuania', 'Republic of Lithuania', 'Europe', 'Northern Europe', '🇱🇹', 24, 56),
  ('LU', 'LUX', 'Luxembourg', 'Grand Duchy of Luxembourg', 'Europe', 'Western Europe', '🇱🇺', 6.16666666, 49.75),
  ('MG', 'MDG', 'Madagascar', 'Republic of Madagascar', 'Africa', 'Eastern Africa', '🇲🇬', 47, -20),
  ('MW', 'MWI', 'Malawi', 'Republic of Malawi', 'Africa', 'Eastern Africa', '🇲🇼', 34, -13.5),
  ('MY', 'MYS', 'Malaysia', 'Malaysia', 'Asia', 'South-Eastern Asia', '🇲🇾', 112.5, 2.5),
  ('MV', 'MDV', 'Maldives', 'Republic of the Maldives', 'Asia', 'Southern Asia', '🇲🇻', 73, 3.25),
  ('ML', 'MLI', 'Mali', 'Republic of Mali', 'Africa', 'Western Africa', '🇲🇱', -4, 17),
  ('MT', 'MLT', 'Malta', 'Republic of Malta', 'Europe', 'Southern Europe', '🇲🇹', 14.58333333, 35.83333333),
  ('MH', 'MHL', 'Marshall Islands', 'Republic of the Marshall Islands', 'Oceania', 'Micronesia', '🇲🇭', 168, 9),
  ('MR', 'MRT', 'Mauritania', 'Islamic Republic of Mauritania', 'Africa', 'Western Africa', '🇲🇷', -12, 20),
  ('MU', 'MUS', 'Mauritius', 'Republic of Mauritius', 'Africa', 'Eastern Africa', '🇲🇺', 57.55, -20.28333333),
  ('MX', 'MEX', 'Mexico', 'United Mexican States', 'Americas', 'North America', '🇲🇽', -102, 23),
  ('FM', 'FSM', 'Micronesia', 'Federated States of Micronesia', 'Oceania', 'Micronesia', '🇫🇲', 158.25, 6.91666666),
  ('MD', 'MDA', 'Moldova', 'Republic of Moldova', 'Europe', 'Eastern Europe', '🇲🇩', 29, 47),
  ('MC', 'MCO', 'Monaco', 'Principality of Monaco', 'Europe', 'Western Europe', '🇲🇨', 7.4, 43.73333333),
  ('MN', 'MNG', 'Mongolia', 'Mongolia', 'Asia', 'Eastern Asia', '🇲🇳', 105, 46),
  ('ME', 'MNE', 'Montenegro', 'Montenegro', 'Europe', 'Southeast Europe', '🇲🇪', 19.3, 42.5),
  ('MA', 'MAR', 'Morocco', 'Kingdom of Morocco', 'Africa', 'Northern Africa', '🇲🇦', -5, 32),
  ('MZ', 'MOZ', 'Mozambique', 'Republic of Mozambique', 'Africa', 'Eastern Africa', '🇲🇿', 35, -18.25),
  ('MM', 'MMR', 'Myanmar', 'Republic of the Union of Myanmar', 'Asia', 'South-Eastern Asia', '🇲🇲', 98, 22),
  ('NA', 'NAM', 'Namibia', 'Republic of Namibia', 'Africa', 'Southern Africa', '🇳🇦', 17, -22),
  ('NR', 'NRU', 'Nauru', 'Republic of Nauru', 'Oceania', 'Micronesia', '🇳🇷', 166.91666666, -0.53333333),
  ('NP', 'NPL', 'Nepal', 'Federal Democratic Republic of Nepal', 'Asia', 'Southern Asia', '🇳🇵', 84, 28),
  ('NL', 'NLD', 'Netherlands', 'Kingdom of the Netherlands', 'Europe', 'Western Europe', '🇳🇱', 5.75, 52.5),
  ('NZ', 'NZL', 'New Zealand', 'New Zealand', 'Oceania', 'Australia and New Zealand', '🇳🇿', 174, -41),
  ('NI', 'NIC', 'Nicaragua', 'Republic of Nicaragua', 'Americas', 'Central America', '🇳🇮', -85, 13),
  ('NE', 'NER', 'Niger', 'Republic of Niger', 'Africa', 'Western Africa', '🇳🇪', 8, 16),
  ('NG', 'NGA', 'Nigeria', 'Federal Republic of Nigeria', 'Africa', 'Western Africa', '🇳🇬', 8, 10),
  ('KP', 'PRK', 'North Korea', 'Democratic People''s Republic of Korea', 'Asia', 'Eastern Asia', '🇰🇵', 127, 40),
  ('MK', 'MKD', 'North Macedonia', 'Republic of North Macedonia', 'Europe', 'Southeast Europe', '🇲🇰', 22, 41.83333333),
  ('NO', 'NOR', 'Norway', 'Kingdom of Norway', 'Europe', 'Northern Europe', '🇳🇴', 10, 62),
  ('OM', 'OMN', 'Oman', 'Sultanate of Oman', 'Asia', 'Western Asia', '🇴🇲', 57, 21),
  ('PK', 'PAK', 'Pakistan', 'Islamic Republic of Pakistan', 'Asia', 'Southern Asia', '🇵🇰', 70, 30),
  ('PW', 'PLW', 'Palau', 'Republic of Palau', 'Oceania', 'Micronesia', '🇵🇼', 134.5, 7.5),
  ('PA', 'PAN', 'Panama', 'Republic of Panama', 'Americas', 'Central America', '🇵🇦', -80, 9),
  ('PG', 'PNG', 'Papua New Guinea', 'Independent State of Papua New Guinea', 'Oceania', 'Melanesia', '🇵🇬', 147, -6),
  ('PY', 'PRY', 'Paraguay', 'Republic of Paraguay', 'Americas', 'South America', '🇵🇾', -58, -23),
  ('PE', 'PER', 'Peru', 'Republic of Peru', 'Americas', 'South America', '🇵🇪', -76, -10),
  ('PH', 'PHL', 'Philippines', 'Republic of the Philippines', 'Asia', 'South-Eastern Asia', '🇵🇭', 122, 13),
  ('PL', 'POL', 'Poland', 'Republic of Poland', 'Europe', 'Central Europe', '🇵🇱', 20, 52),
  ('PT', 'PRT', 'Portugal', 'Portuguese Republic', 'Europe', 'Southern Europe', '🇵🇹', -8, 39.5),
  ('QA', 'QAT', 'Qatar', 'State of Qatar', 'Asia', 'Western Asia', '🇶🇦', 51.25, 25.5),
  ('CG', 'COG', 'Republic of the Congo', 'Republic of the Congo', 'Africa', 'Middle Africa', '🇨🇬', 15, -1),
  ('RO', 'ROU', 'Romania', 'Romania', 'Europe', 'Southeast Europe', '🇷🇴', 25, 46),
  ('RU', 'RUS', 'Russia', 'Russian Federation', 'Europe', 'Eastern Europe', '🇷🇺', 100, 60),
  ('RW', 'RWA', 'Rwanda', 'Republic of Rwanda', 'Africa', 'Eastern Africa', '🇷🇼', 30, -2),
  ('KN', 'KNA', 'Saint Kitts and Nevis', 'Federation of Saint Christopher and Nevis', 'Americas', 'Caribbean', '🇰🇳', -62.75, 17.33333333),
  ('LC', 'LCA', 'Saint Lucia', 'Saint Lucia', 'Americas', 'Caribbean', '🇱🇨', -60.96666666, 13.88333333),
  ('VC', 'VCT', 'Saint Vincent and the Grenadines', 'Saint Vincent and the Grenadines', 'Americas', 'Caribbean', '🇻🇨', -61.2, 13.25),
  ('WS', 'WSM', 'Samoa', 'Independent State of Samoa', 'Oceania', 'Polynesia', '🇼🇸', -172.33333333, -13.58333333),
  ('SM', 'SMR', 'San Marino', 'Most Serene Republic of San Marino', 'Europe', 'Southern Europe', '🇸🇲', 12.41666666, 43.76666666),
  ('ST', 'STP', 'São Tomé and Príncipe', 'Democratic Republic of São Tomé and Príncipe', 'Africa', 'Middle Africa', '🇸🇹', 7, 1),
  ('SA', 'SAU', 'Saudi Arabia', 'Kingdom of Saudi Arabia', 'Asia', 'Western Asia', '🇸🇦', 45, 25),
  ('SN', 'SEN', 'Senegal', 'Republic of Senegal', 'Africa', 'Western Africa', '🇸🇳', -14, 14),
  ('RS', 'SRB', 'Serbia', 'Republic of Serbia', 'Europe', 'Southeast Europe', '🇷🇸', 21, 44),
  ('SC', 'SYC', 'Seychelles', 'Republic of Seychelles', 'Africa', 'Eastern Africa', '🇸🇨', 55.66666666, -4.58333333),
  ('SL', 'SLE', 'Sierra Leone', 'Republic of Sierra Leone', 'Africa', 'Western Africa', '🇸🇱', -11.5, 8.5),
  ('SG', 'SGP', 'Singapore', 'Republic of Singapore', 'Asia', 'South-Eastern Asia', '🇸🇬', 103.8, 1.36666666),
  ('SK', 'SVK', 'Slovakia', 'Slovak Republic', 'Europe', 'Central Europe', '🇸🇰', 19.5, 48.66666666),
  ('SI', 'SVN', 'Slovenia', 'Republic of Slovenia', 'Europe', 'Central Europe', '🇸🇮', 14.81666666, 46.11666666),
  ('SB', 'SLB', 'Solomon Islands', 'Solomon Islands', 'Oceania', 'Melanesia', '🇸🇧', 159, -8),
  ('SO', 'SOM', 'Somalia', 'Federal Republic of Somalia', 'Africa', 'Eastern Africa', '🇸🇴', 49, 10),
  ('ZA', 'ZAF', 'South Africa', 'Republic of South Africa', 'Africa', 'Southern Africa', '🇿🇦', 24, -29),
  ('KR', 'KOR', 'South Korea', 'Republic of Korea', 'Asia', 'Eastern Asia', '🇰🇷', 127.5, 37),
  ('SS', 'SSD', 'South Sudan', 'Republic of South Sudan', 'Africa', 'Middle Africa', '🇸🇸', 30, 7),
  ('ES', 'ESP', 'Spain', 'Kingdom of Spain', 'Europe', 'Southern Europe', '🇪🇸', -4, 40),
  ('LK', 'LKA', 'Sri Lanka', 'Democratic Socialist Republic of Sri Lanka', 'Asia', 'Southern Asia', '🇱🇰', 81, 7),
  ('SD', 'SDN', 'Sudan', 'Republic of the Sudan', 'Africa', 'Northern Africa', '🇸🇩', 30, 15),
  ('SR', 'SUR', 'Suriname', 'Republic of Suriname', 'Americas', 'South America', '🇸🇷', -56, 4),
  ('SE', 'SWE', 'Sweden', 'Kingdom of Sweden', 'Europe', 'Northern Europe', '🇸🇪', 15, 62),
  ('CH', 'CHE', 'Switzerland', 'Swiss Confederation', 'Europe', 'Western Europe', '🇨🇭', 8, 47),
  ('SY', 'SYR', 'Syria', 'Syrian Arab Republic', 'Asia', 'Western Asia', '🇸🇾', 38, 35),
  ('TJ', 'TJK', 'Tajikistan', 'Republic of Tajikistan', 'Asia', 'Central Asia', '🇹🇯', 71, 39),
  ('TZ', 'TZA', 'Tanzania', 'United Republic of Tanzania', 'Africa', 'Eastern Africa', '🇹🇿', 35, -6),
  ('TH', 'THA', 'Thailand', 'Kingdom of Thailand', 'Asia', 'South-Eastern Asia', '🇹🇭', 100, 15),
  ('TL', 'TLS', 'Timor-Leste', 'Democratic Republic of Timor-Leste', 'Asia', 'South-Eastern Asia', '🇹🇱', 125.91666666, -8.83333333),
  ('TG', 'TGO', 'Togo', 'Togolese Republic', 'Africa', 'Western Africa', '🇹🇬', 1.16666666, 8),
  ('TO', 'TON', 'Tonga', 'Kingdom of Tonga', 'Oceania', 'Polynesia', '🇹🇴', -175, -20),
  ('TT', 'TTO', 'Trinidad and Tobago', 'Republic of Trinidad and Tobago', 'Americas', 'Caribbean', '🇹🇹', -61, 11),
  ('TN', 'TUN', 'Tunisia', 'Tunisian Republic', 'Africa', 'Northern Africa', '🇹🇳', 9, 34),
  ('TR', 'TUR', 'Türkiye', 'Republic of Türkiye', 'Asia', 'Western Asia', '🇹🇷', 35, 39),
  ('TM', 'TKM', 'Turkmenistan', 'Turkmenistan', 'Asia', 'Central Asia', '🇹🇲', 60, 40),
  ('TV', 'TUV', 'Tuvalu', 'Tuvalu', 'Oceania', 'Polynesia', '🇹🇻', 178, -8),
  ('UG', 'UGA', 'Uganda', 'Republic of Uganda', 'Africa', 'Eastern Africa', '🇺🇬', 32, 1),
  ('UA', 'UKR', 'Ukraine', 'Ukraine', 'Europe', 'Eastern Europe', '🇺🇦', 32, 49),
  ('AE', 'ARE', 'United Arab Emirates', 'United Arab Emirates', 'Asia', 'Western Asia', '🇦🇪', 54, 24),
  ('GB', 'GBR', 'United Kingdom', 'United Kingdom of Great Britain and Northern Ireland', 'Europe', 'Northern Europe', '🇬🇧', -2, 54),
  ('US', 'USA', 'United States', 'United States of America', 'Americas', 'North America', '🇺🇸', -97, 38),
  ('UY', 'URY', 'Uruguay', 'Oriental Republic of Uruguay', 'Americas', 'South America', '🇺🇾', -56, -33),
  ('UZ', 'UZB', 'Uzbekistan', 'Republic of Uzbekistan', 'Asia', 'Central Asia', '🇺🇿', 64, 41),
  ('VU', 'VUT', 'Vanuatu', 'Republic of Vanuatu', 'Oceania', 'Melanesia', '🇻🇺', 167, -16),
  ('VA', 'VAT', 'Vatican City', 'Vatican City State', 'Europe', 'Southern Europe', '🇻🇦', 12.45, 41.9),
  ('VE', 'VEN', 'Venezuela', 'Bolivarian Republic of Venezuela', 'Americas', 'South America', '🇻🇪', -66, 8),
  ('VN', 'VNM', 'Vietnam', 'Socialist Republic of Vietnam', 'Asia', 'South-Eastern Asia', '🇻🇳', 107.83333333, 16.16666666),
  ('YE', 'YEM', 'Yemen', 'Republic of Yemen', 'Asia', 'Western Asia', '🇾🇪', 48, 15),
  ('ZM', 'ZMB', 'Zambia', 'Republic of Zambia', 'Africa', 'Eastern Africa', '🇿🇲', 30, -15),
  ('ZW', 'ZWE', 'Zimbabwe', 'Republic of Zimbabwe', 'Africa', 'Eastern Africa', '🇿🇼', 30, -20)
on conflict (iso_a2) do update set
  iso_a3        = excluded.iso_a3,
  name          = excluded.name,
  official_name = excluded.official_name,
  region        = excluded.region,
  subregion     = excluded.subregion,
  flag_emoji    = excluded.flag_emoji,
  centroid_lng  = excluded.centroid_lng,
  centroid_lat  = excluded.centroid_lat;


-- ===== source: supabase\scripts\seed-dev.sql =====

-- =============================================================================
-- GastroVoyage — Standalone DEV seed for the *remote* Supabase project.
--
-- Run this in the Supabase Dashboard -> SQL Editor when you don't have
-- the Supabase CLI / `db reset` plumbed yet. Safe to re-run (idempotent).
--
-- Creates two dev users and 4 visits each:
--   vusal@gastrovoyage.dev   / password: gastrovoyage
--   sakina@gastrovoyage.dev  / password: gastrovoyage
--
-- Visits: Azerbaijan, Italy, Mexico, Japan.
-- =============================================================================

do $$
declare
  v_vusal_id  uuid;
  v_sakina_id uuid;
  v_az_id     uuid;
  v_it_id     uuid;
  v_mx_id     uuid;
  v_jp_id     uuid;
begin
  -- ---------------- VUSAL ----------------
  select id into v_vusal_id from auth.users where email = 'vusal@gastrovoyage.dev';

  if v_vusal_id is null then
    v_vusal_id := gen_random_uuid();
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      v_vusal_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'vusal@gastrovoyage.dev',
      crypt('gastrovoyage', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"display_name":"Vusal"}'::jsonb,
      '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_vusal_id,
      jsonb_build_object('sub', v_vusal_id::text, 'email', 'vusal@gastrovoyage.dev'),
      'email', v_vusal_id::text, now(), now(), now()
    );
  end if;

  -- ---------------- SAKINA ----------------
  select id into v_sakina_id from auth.users where email = 'sakina@gastrovoyage.dev';

  if v_sakina_id is null then
    v_sakina_id := gen_random_uuid();
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      v_sakina_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'sakina@gastrovoyage.dev',
      crypt('gastrovoyage', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"display_name":"Sakina"}'::jsonb,
      '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_sakina_id,
      jsonb_build_object('sub', v_sakina_id::text, 'email', 'sakina@gastrovoyage.dev'),
      'email', v_sakina_id::text, now(), now(), now()
    );
  end if;

  -- Profiles: trigger should have created them, but enforce content for dev.
  insert into public.profiles (id, display_name, home_city, bio)
  values
    (v_vusal_id,  'Vusal',  'Baku', 'Co-founder of GastroVoyage. Loves smoky aubergine and a sharp mezze.'),
    (v_sakina_id, 'Sakina', 'Baku', 'Co-founder of GastroVoyage. Pasta-first, dessert-always.')
  on conflict (id) do update set
    display_name = excluded.display_name,
    home_city    = excluded.home_city,
    bio          = excluded.bio;

  -- ---------------- Visits ----------------
  select id into v_az_id from public.countries where iso_a2 = 'AZ';
  select id into v_it_id from public.countries where iso_a2 = 'IT';
  select id into v_mx_id from public.countries where iso_a2 = 'MX';
  select id into v_jp_id from public.countries where iso_a2 = 'JP';

  if v_az_id is null or v_it_id is null or v_mx_id is null or v_jp_id is null then
    raise exception 'Countries master list not seeded yet — run 20260514000200_seed_countries.sql first.';
  end if;

  insert into public.visits (user_id, country_id, rating, notes, visited_on)
  values
    (v_vusal_id,  v_az_id, 5, 'Plov at Şah Plov in Baku — childhood on a plate.',                  current_date - 45),
    (v_vusal_id,  v_it_id, 5, 'Cacio e pepe in Trastevere. Perfect black pepper bite.',            current_date - 32),
    (v_vusal_id,  v_mx_id, 4, 'Birria tacos with consommé in Mexico City. Smoky and rich.',        current_date - 20),
    (v_vusal_id,  v_jp_id, 5, 'Omakase sushi in Ginza. The uni course changed my life.',           current_date - 7),

    (v_sakina_id, v_az_id, 5, 'Dushbara at home with Mom — nothing beats it.',                     current_date - 50),
    (v_sakina_id, v_it_id, 5, 'Carbonara done right in Roma. Egg-yolk velvety.',                   current_date - 33),
    (v_sakina_id, v_mx_id, 5, 'Mole negro in Oaxaca. 30 ingredients, one religious experience.',   current_date - 18),
    (v_sakina_id, v_jp_id, 4, 'Wagyu shabu-shabu in Kobe. Butter that thinks it''s beef.',         current_date - 5)
  on conflict (user_id, country_id) do update set
    rating     = excluded.rating,
    notes      = excluded.notes,
    visited_on = excluded.visited_on;

  -- Award "first_steps" to both
  insert into public.user_badges (user_id, badge_code)
  values
    (v_vusal_id,  'first_steps'),
    (v_sakina_id, 'first_steps')
  on conflict do nothing;

  raise notice 'Seeded dev users: vusal@gastrovoyage.dev, sakina@gastrovoyage.dev (password: gastrovoyage)';
end $$;

