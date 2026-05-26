# GastroVoyage MVP Data Model

## Entities

- `dishes`: world dishes shown on map.
- `restaurants`: Baku restaurants.
- `restaurant_dishes`: many-to-many dish availability with confidence score.
- `user_tastings`: user tasting events.
- `user_tasting_photos`: optional proof photos per tasting.
- `challenges`: target-based challenge definitions.

## Minimal Relationship Rules

- One dish can be linked to many restaurants.
- One restaurant can serve many dishes.
- One tasting belongs to one user, one dish, and one restaurant.
- One tasting can have zero or more photos.

## Moderation

`user_tasting_photos.moderation_status` values:
- `pending`
- `approved`
- `rejected`

## Provenance Extension (Phase 2)

Add to curated entities:
- `source_type`
- `source_note`
- `verified_by`
- `verified_at`

## Monetization Extension (Phase 3)

Suggested additional entities:

- `partners`: restaurant partner account profile.
- `campaigns`: sponsored campaign configuration.
- `placements`: concrete promoted slots bound to screen contexts.
- `placement_metrics`: impressions/clicks/conversion proxies.
