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
