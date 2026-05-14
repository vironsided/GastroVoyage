export interface Restaurant {
  id: string;
  name: string;
  countryId: string;
  city: string;
  address: string | null;
  lng: number | null;
  lat: number | null;
  cuisineTags: string[];
  isPartner: boolean;
  commissionRate: number | null;
  partnerSince: string | null;
  verifiedAt: string | null;
  phone: string | null;
  website: string | null;
  createdAt: string;
}

export interface PartnerRestaurant extends Restaurant {
  isPartner: true;
  commissionRate: number;
}

export const isPartner = (r: Restaurant): r is PartnerRestaurant =>
  r.isPartner === true && r.commissionRate !== null;
