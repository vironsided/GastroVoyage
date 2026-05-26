# Business Readiness (MVP)

## Sponsored Placement Model

### Placement Types

1. **Promoted Restaurant Card** in dish detail list.
2. **Featured Cuisine Campaign** on challenge screen.
3. **City Discovery Slot** on map feed section.

### Labeling Rules

- Sponsored content must always include a clear `Promoted` label.
- Ranking logic must separate sponsored boost from organic relevance.

## Partner Onboarding Procedure

1. Restaurant submits registration form.
2. Admin verifies legal entity and contact ownership.
3. Admin links partner to dish coverage records.
4. Campaign and budget are configured in admin panel.
5. Weekly performance report shared with partner.

## KPI Baseline

- CTR on promoted cards.
- Dish-to-restaurant detail click-through.
- Conversion proxy: call/map-open/outbound action.
- Retention impact versus organic-only flow.

## Content Governance

- Any partner media goes through moderation before publishing.
- User proof-photos are not reused for ads without explicit consent.
- No misleading dish-availability claims.

## Moderation Policy (Operational)

- `pending`: awaiting review.
- `approved`: visible in user and partner surfaces.
- `rejected`: hidden, with rejection reason stored in audit log.

## Admin Requirements

- Filter by partner, campaign, and moderation status.
- Manual override with audit trail (`who`, `when`, `reason`).
- Soft-delete for campaigns to preserve reporting history.
