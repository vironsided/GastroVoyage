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
