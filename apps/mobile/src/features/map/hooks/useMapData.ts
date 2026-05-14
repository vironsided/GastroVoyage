import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import type { CountryShape, WorldShapeAtlas } from '@gastrovoyage/shared';

import worldShapes from '@gastrovoyage/shared/data/world-shapes.json';
import { supabase } from '../../../lib/supabase';
import { useAuth } from '../../../providers/AuthProvider';

const atlas = worldShapes as WorldShapeAtlas;

export interface UserVisitSummary {
  countryId: string;
  isoA2: string;
  isoA3: string;
  visitedOn: string;
  rating: number | null;
  notes: string | null;
}

/**
 * Top-level data hook for the world map. Returns:
 *   - the (memoized, parsed) world atlas
 *   - the current user's visits as a Map keyed by iso_a3 for O(1) lookups
 *
 * The world atlas is shipped in the bundle; the visit list is fetched live.
 */
export function useMapData() {
  const { user } = useAuth();

  const visitsQuery = useQuery({
    queryKey: ['map', 'visits', user?.id],
    enabled: !!user,
    staleTime: 60_000,
    queryFn: async (): Promise<UserVisitSummary[]> => {
      if (!user) return [];
      const { data, error } = await supabase
        .from('visits')
        .select(
          'country_id, rating, notes, visited_on, countries(iso_a2, iso_a3)',
        )
        .eq('user_id', user.id);

      if (error) throw error;
      type Row = {
        country_id: string;
        rating: number | null;
        notes: string | null;
        visited_on: string;
        countries: { iso_a2: string; iso_a3: string } | null;
      };
      const rows = (data ?? []) as Row[];
      return rows
        .filter((r): r is typeof r & { countries: { iso_a2: string; iso_a3: string } } =>
          r.countries !== null,
        )
        .map((r) => ({
          countryId: r.country_id,
          isoA2: r.countries.iso_a2,
          isoA3: r.countries.iso_a3,
          visitedOn: r.visited_on,
          rating: r.rating,
          notes: r.notes,
        }));
    },
  });

  const visitsByIsoA3 = useMemo(() => {
    const map = new Map<string, UserVisitSummary>();
    for (const v of visitsQuery.data ?? []) map.set(v.isoA3, v);
    return map;
  }, [visitsQuery.data]);

  return {
    atlas,
    features: atlas.features as CountryShape[],
    visitsByIsoA3,
    isLoading: visitsQuery.isLoading,
    error: visitsQuery.error,
    refetch: visitsQuery.refetch,
  };
}
