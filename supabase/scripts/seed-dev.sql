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
