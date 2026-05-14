import { createClient, type SupabaseClientOptions } from '@supabase/supabase-js';
import type { Database } from './types.generated';

export interface CreateBrowserSupabaseArgs {
  url: string;
  anonKey: string;
  /**
   * Optional storage adapter. Pass `AsyncStorage` on React Native, `undefined`
   * on web (browser localStorage is the default). On Next.js RSC, prefer the
   * cookie-based `@supabase/ssr` client instead of this factory.
   */
  storage?: SupabaseClientOptions<'public'>['auth'] extends infer A
    ? A extends { storage?: infer S }
      ? S
      : never
    : never;
  /** Persist auth across reloads. Default true. */
  persistSession?: boolean;
}

/**
 * Single factory for an anon (publishable) Supabase client.
 *
 * Use this in:
 *   - the mobile app (with AsyncStorage)
 *   - the admin panel's client components
 *
 * Do NOT use this with the service-role key — see `./admin.ts`.
 */
export function createBrowserSupabase({
  url,
  anonKey,
  storage,
  persistSession = true,
}: CreateBrowserSupabaseArgs) {
  if (!url || !anonKey) {
    throw new Error(
      '[GastroVoyage] Missing Supabase URL or anon key. Check your env files (see docs/setup-supabase.md).',
    );
  }

  return createClient<Database>(url, anonKey, {
    auth: {
      storage,
      persistSession,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
  });
}

export type SupabaseBrowser = ReturnType<typeof createBrowserSupabase>;
