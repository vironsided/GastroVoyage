export interface Visit {
  id: string;
  userId: string;
  countryId: string;
  restaurantId: string | null;
  rating: number | null;
  notes: string | null;
  visitedOn: string;
  photoPath: string | null;
  createdAt: string;
  updatedAt: string;
}

/** A visit row joined with its country — what most screens actually want. */
export interface VisitWithCountry extends Visit {
  country: {
    iso_a2: string;
    iso_a3: string;
    name: string;
    flag_emoji: string;
    region: string;
  };
}

export interface CheckIn {
  id: string;
  userId: string;
  restaurantId: string;
  visitId: string | null;
  checkedInAt: string;
  gpsLat: number | null;
  gpsLng: number | null;
  distanceM: number | null;
  isVerified: boolean;
}
