# GastroVoyage — Restructure & UX Overhaul (Design Spec)

Date: 2026-06-17
Status: approved direction (owner answered the 4 strategic forks); phased execution

## Why

The app works but feels chaotic. Evidence-backed audit (file:line) found a clear
structural root cause, not a vibe:

1. **Half the app is hidden behind a 44px avatar.** `account_settings_screen.dart`
   is a 2,572-line megascreen and the ONLY door to Friends, Stories, Achievements,
   My Couple, Privacy, Share Profile. No "Profile/You" tab exists. (This is the
   owner's literal "everything is in Settings" complaint.)
2. **The core verb is undiscoverable.** "Log a tasting" has exactly ONE entry point
   (`explore/dish_detail_screen.dart:234`); there is no FAB or `+` anywhere.
3. **Duplicate doors** (one feature reachable from 2–4 places, no canonical home).
4. **Naming chaos:** Journal / Vault / scrapbook / Passport all name one area.
5. **Home is a promo wall** (~9–11 modules); the user's own data sits below the fold.
6. **Dev-jargon error copy** ("CUSTOMS IS OFFLINE / port 8000").
7. **Dead second backend** (unmounted SQLAlchemy stack: `admin`/`dishes`/`tastings`
   routers, `app/models`, `app/db`, `seed/baku_seed.py`); `admin.py` has no auth.
8. **Baku map data is hardcoded & approximate** → restaurants plot in the sea.

## Decisions (owner)

- **Primary loop: Baku restaurant guide is the hero.** Discovering where to eat in
  Baku is the headline value. → invest in real, governed Baku restaurant data.
- **Both maps first-class:** World passport AND Baku guide are both primary.
- **Couples & AI stay flagship** — keep them prominent (do NOT demote/hide), but
  organize Home so they don't crowd out the user's own data.
- **Cleanup approved:** delete the dead SQLAlchemy backend, empty feature dirs, and
  remove the Design Showcase from the production menu.

## Target Information Architecture (5-tab bottom nav)

```
Home      Hero Baku discovery (nearby/featured) + the user's progress + a prominent
          "Log a tasting" CTA. Flagship Couples/AI cards kept, grouped into clear
          sections so Home leads with content, not a promo stack.
Map       World/Baku toggle, both first-class (remove the dead 3rd "Globe" state).
          Empty state + "Log a visit here" CTA from the country/restaurant card.
Explore   Dish/ingredient catalog (as today) + clearer "Log this dish" CTA.
Passport  Single home of the collection: visit list + flip-book + Achievements +
          Privacy/Share. Rename Vault/Journal/scrapbook → "Passport" everywhere.
You ✦NEW  Identity, My Couple, Friends & Followers, Stories, and one "Settings" link.
Settings  Slimmed to ~7 rows: Theme, Notifications, About, Privacy, Rate, Help,
          Delete Account. Design Showcase gated behind kDebugMode (off the menu).
```

## Phased plan

**Phase 1 — Quick wins (low effort, high impact, low risk):**
- Fix Baku coordinates plotting in the sea (Sumaq, Texas BBQ; scan others).
- Replace dev-jargon error copy with human copy + Retry buttons (error_card,
  explore "Customs offline", home Passport card, badges wall).
- Add a global "Log a tasting" entry point (FAB / nav `+`) wired to the existing
  log form; wire the Passport/Map empty-state CTAs to it.
- Remove the dead "Globe" 3rd map state.

**Phase 0/cross — Cleanup (low risk):**
- Delete dead backend SQLAlchemy stack (`admin`/`dishes`/`tastings`, `app/models`,
  `app/db`, `seed/baku_seed.py`) + 4 empty feature dirs; gate Design Showcase.

**Phase 2 — De-bury Settings (structural):**
- Add the `You/Profile` tab; move Friends/Stories/Achievements/My Couple onto it;
  pick one canonical home per feature (kill duplicate doors); slim Settings.
- Rename the 4th tab + internal strings to "Passport".

**Phase 3 — Home reorganization:**
- Group Home into sections (Baku discovery, Your passport, Recent, flagship
  Couples/AI). Keep Couples/AI prominent but conditional where it makes sense.

**Phase 4 — Baku-as-hero data model (the big investment, since Baku is the hero):**
- Promote Baku restaurants to a Supabase table with real geocoding + an admin path,
  `restaurant_id` FK on visits (replace fragile name-string matching), and curate
  real venues (the current 29 are approximate placeholders). Add a test asserting
  every pin sits north of the Baku-Bay waterline (regression guard).

## Notes / risks

- Map coordinate quick-fix is a stopgap; Phase 4 replaces the hardcoded list.
- Keep Couples/AI visible per owner decision — reorganization, not removal.
- Backend deletions: verify no mounted router / mobile caller before removing
  (audit verified, but re-confirm at execution).
