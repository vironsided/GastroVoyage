/**
 * Placeholder typing of the Supabase database.
 *
 * Run `pnpm db:types` after applying migrations to overwrite this file with
 * the real generated types from `supabase gen types typescript --linked`.
 *
 * Until then, this stub matches the schema in
 * `supabase/migrations/20260514000000_init_schema.sql` so the TS projects
 * compile.
 *
 * Note: we use `type` rather than `interface` for the row/insert/update
 * shapes. This is required so that the resulting type structurally extends
 * `Record<string, unknown>` (the constraint the Supabase typed client uses).
 * Interfaces are open and don't satisfy that constraint.
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

// -- profiles -----------------------------------------------------------------
type ProfileRow = {
  id: string;
  display_name: string;
  avatar_url: string | null;
  home_city: string | null;
  bio: string | null;
  created_at: string;
  updated_at: string;
};
type ProfileInsert = {
  id: string;
  display_name: string;
  avatar_url?: string | null;
  home_city?: string | null;
  bio?: string | null;
  created_at?: string;
  updated_at?: string;
};

// -- countries ----------------------------------------------------------------
type CountryRow = {
  id: string;
  iso_a2: string;
  iso_a3: string;
  name: string;
  official_name: string | null;
  region: string;
  subregion: string | null;
  flag_emoji: string;
  centroid_lng: number;
  centroid_lat: number;
  created_at: string;
};
type CountryInsert = {
  id?: string;
  iso_a2: string;
  iso_a3: string;
  name: string;
  official_name?: string | null;
  region: string;
  subregion?: string | null;
  flag_emoji: string;
  centroid_lng: number;
  centroid_lat: number;
  created_at?: string;
};

// -- cuisines -----------------------------------------------------------------
type CuisineRow = {
  id: string;
  country_id: string;
  name: string;
  description: string | null;
  signature_dish: string | null;
  image_url: string | null;
  created_at: string;
  updated_at: string;
};
type CuisineInsert = {
  id?: string;
  country_id: string;
  name: string;
  description?: string | null;
  signature_dish?: string | null;
  image_url?: string | null;
  created_at?: string;
  updated_at?: string;
};

// -- restaurants --------------------------------------------------------------
type RestaurantRow = {
  id: string;
  name: string;
  country_id: string;
  city: string;
  address: string | null;
  lng: number | null;
  lat: number | null;
  cuisine_tags: string[];
  is_partner: boolean;
  commission_rate: number | null;
  partner_since: string | null;
  verified_at: string | null;
  phone: string | null;
  website: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};
type RestaurantInsert = {
  id?: string;
  name: string;
  country_id: string;
  city: string;
  address?: string | null;
  lng?: number | null;
  lat?: number | null;
  cuisine_tags?: string[];
  is_partner?: boolean;
  commission_rate?: number | null;
  partner_since?: string | null;
  verified_at?: string | null;
  phone?: string | null;
  website?: string | null;
  created_by?: string | null;
  created_at?: string;
  updated_at?: string;
};

// -- visits -------------------------------------------------------------------
type VisitRow = {
  id: string;
  user_id: string;
  country_id: string;
  restaurant_id: string | null;
  rating: number | null;
  notes: string | null;
  visited_on: string;
  photo_path: string | null;
  created_at: string;
  updated_at: string;
};
type VisitInsert = {
  id?: string;
  user_id: string;
  country_id: string;
  restaurant_id?: string | null;
  rating?: number | null;
  notes?: string | null;
  visited_on?: string;
  photo_path?: string | null;
  created_at?: string;
  updated_at?: string;
};

// -- check_ins ----------------------------------------------------------------
type CheckInRow = {
  id: string;
  user_id: string;
  restaurant_id: string;
  visit_id: string | null;
  checked_in_at: string;
  gps_lat: number | null;
  gps_lng: number | null;
  distance_m: number | null;
  is_verified: boolean;
};
type CheckInInsert = {
  id?: string;
  user_id: string;
  restaurant_id: string;
  visit_id?: string | null;
  checked_in_at?: string;
  gps_lat?: number | null;
  gps_lng?: number | null;
  distance_m?: number | null;
  is_verified?: boolean;
};

// -- badges -------------------------------------------------------------------
type BadgeRow = {
  code: string;
  title: string;
  description: string;
  region: string | null;
  threshold: number | null;
  icon: string | null;
  sort_order: number;
};
type BadgeInsert = {
  code: string;
  title: string;
  description: string;
  region?: string | null;
  threshold?: number | null;
  icon?: string | null;
  sort_order?: number;
};

// -- user_badges --------------------------------------------------------------
type UserBadgeRow = {
  user_id: string;
  badge_code: string;
  earned_at: string;
};
type UserBadgeInsert = {
  user_id: string;
  badge_code: string;
  earned_at?: string;
};

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: ProfileRow;
        Insert: ProfileInsert;
        Update: Partial<ProfileInsert>;
        Relationships: [];
      };
      countries: {
        Row: CountryRow;
        Insert: CountryInsert;
        Update: Partial<CountryInsert>;
        Relationships: [];
      };
      cuisines: {
        Row: CuisineRow;
        Insert: CuisineInsert;
        Update: Partial<CuisineInsert>;
        Relationships: [
          {
            foreignKeyName: 'cuisines_country_id_fkey';
            columns: ['country_id'];
            isOneToOne: false;
            referencedRelation: 'countries';
            referencedColumns: ['id'];
          },
        ];
      };
      restaurants: {
        Row: RestaurantRow;
        Insert: RestaurantInsert;
        Update: Partial<RestaurantInsert>;
        Relationships: [
          {
            foreignKeyName: 'restaurants_country_id_fkey';
            columns: ['country_id'];
            isOneToOne: false;
            referencedRelation: 'countries';
            referencedColumns: ['id'];
          },
        ];
      };
      visits: {
        Row: VisitRow;
        Insert: VisitInsert;
        Update: Partial<VisitInsert>;
        Relationships: [
          {
            foreignKeyName: 'visits_country_id_fkey';
            columns: ['country_id'];
            isOneToOne: false;
            referencedRelation: 'countries';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'visits_restaurant_id_fkey';
            columns: ['restaurant_id'];
            isOneToOne: false;
            referencedRelation: 'restaurants';
            referencedColumns: ['id'];
          },
        ];
      };
      check_ins: {
        Row: CheckInRow;
        Insert: CheckInInsert;
        Update: Partial<CheckInInsert>;
        Relationships: [
          {
            foreignKeyName: 'check_ins_restaurant_id_fkey';
            columns: ['restaurant_id'];
            isOneToOne: false;
            referencedRelation: 'restaurants';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'check_ins_visit_id_fkey';
            columns: ['visit_id'];
            isOneToOne: false;
            referencedRelation: 'visits';
            referencedColumns: ['id'];
          },
        ];
      };
      badges: {
        Row: BadgeRow;
        Insert: BadgeInsert;
        Update: Partial<BadgeInsert>;
        Relationships: [];
      };
      user_badges: {
        Row: UserBadgeRow;
        Insert: UserBadgeInsert;
        Update: Partial<UserBadgeInsert>;
        Relationships: [
          {
            foreignKeyName: 'user_badges_badge_code_fkey';
            columns: ['badge_code'];
            isOneToOne: false;
            referencedRelation: 'badges';
            referencedColumns: ['code'];
          },
        ];
      };
    };
    Views: Record<string, never>;
    Functions: {
      is_admin: {
        Args: Record<string, never>;
        Returns: boolean;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
