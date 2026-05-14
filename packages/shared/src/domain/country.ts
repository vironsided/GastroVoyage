export type Region = 'Africa' | 'Americas' | 'Asia' | 'Europe' | 'Oceania' | 'Antarctic';

export interface Country {
  id: string;
  isoA2: string;
  isoA3: string;
  name: string;
  officialName: string | null;
  region: Region;
  subregion: string | null;
  flagEmoji: string;
  centroidLng: number;
  centroidLat: number;
}

/** Country shape as stored in packages/shared/src/data/countries.json (pre-DB). */
export interface SeedCountry {
  iso_a2: string;
  iso_a3: string;
  name: string;
  official_name: string | null;
  region: Region;
  subregion: string | null;
  flag_emoji: string;
  centroid_lng: number;
  centroid_lat: number;
}

/**
 * A single country feature in the pre-baked Skia world atlas.
 * Coordinates are in the normalized projection space defined by
 * `WorldShapeAtlas.width / .height` (currently 1000x500).
 */
export interface CountryShape {
  iso_a2: string;
  iso_a3: string;
  name: string;
  region: Region;
  /** Skia / SVG path string, pre-projected with d3-geo geoNaturalEarth1. */
  path: string;
  /** Centroid for placing the Instax stamp / dot. */
  cx: number;
  cy: number;
  /** Projected bounding box, useful for hit-testing. */
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

export interface WorldShapeAtlas {
  width: number;
  height: number;
  features: CountryShape[];
}
