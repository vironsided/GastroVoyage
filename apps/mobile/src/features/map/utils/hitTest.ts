import type { CountryShape } from '@gastrovoyage/shared';

/**
 * Hit-test a point (in atlas coordinates) against the country features.
 *
 * Strategy:
 *   1. Filter to features whose bbox contains the point (cheap).
 *   2. From those candidates, pick the smallest-bbox one (i.e. the most
 *      specific). This is a pragmatic substitute for true point-in-polygon
 *      — Natural Earth countries don't overlap, but the bbox test alone
 *      can return overlapping bbox matches (e.g. Italy + Vatican area). The
 *      "smallest bbox containing the point" heuristic resolves it cleanly.
 *   3. If nothing matches, fall back to a "nearest centroid within
 *      tolerance" search — needed for micro-states that are sub-pixel.
 */
export function hitTestAtlas(
  features: CountryShape[],
  x: number,
  y: number,
  /** Tolerance for the centroid-distance fallback, in atlas units. */
  tolerance = 6,
): CountryShape | null {
  let best: CountryShape | null = null;
  let bestArea = Infinity;

  for (const f of features) {
    if (x < f.minX || x > f.maxX || y < f.minY || y > f.maxY) continue;
    const area = (f.maxX - f.minX) * (f.maxY - f.minY);
    if (area < bestArea) {
      best = f;
      bestArea = area;
    }
  }
  if (best) return best;

  // Fallback: nearest centroid within tolerance.
  let nearest: CountryShape | null = null;
  let nearestDist = tolerance;
  for (const f of features) {
    const dx = f.cx - x;
    const dy = f.cy - y;
    const d = Math.sqrt(dx * dx + dy * dy);
    if (d < nearestDist) {
      nearest = f;
      nearestDist = d;
    }
  }
  return nearest;
}
