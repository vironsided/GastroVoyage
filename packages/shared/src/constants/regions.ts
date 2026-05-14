import type { Region } from '../domain/country';

export const REGIONS: readonly Region[] = [
  'Africa',
  'Americas',
  'Asia',
  'Europe',
  'Oceania',
] as const;

export const REGION_TO_BADGE: Record<Region, string | null> = {
  Africa: 'african_pioneer',
  Americas: 'american_trailblazer',
  Asia: 'asian_explorer',
  Europe: 'european_voyager',
  Oceania: 'oceania_sailor',
  Antarctic: null,
};

export const REGION_THRESHOLDS: Record<Region, number> = {
  Africa: 10,
  Americas: 10,
  Asia: 10,
  Europe: 10,
  Oceania: 5,
  Antarctic: 0,
};

export const TOTAL_COUNTRIES = 195 as const;
