# ADR 0001: Tech Stack for GastroVoyage MVP

## Status

Accepted

## Context

MVP needs fast delivery for:
- mobile app (Flutter),
- map interactions,
- admin/content workflows,
- geospatial-friendly database,
- iterative product experimentation.

## Decision

- Mobile: Flutter.
- Backend: FastAPI (Python) for rapid iteration.
- Database: PostgreSQL (PostGIS-ready schema).
- Maps: Mapbox for flexible mobile map UX and style control.
- Storage: S3-compatible object storage for tasting photos.

## Consequences

- Fast startup speed for API development and experimentation.
- Clean migration path to more complex microservices if needed.
- Team can iterate on map and personalization quickly.
