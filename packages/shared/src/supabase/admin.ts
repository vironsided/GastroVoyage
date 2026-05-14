import { createClient } from '@supabase/supabase-js';
import type { Database } from './types.generated';

export interface CreateServiceRoleSupabaseArgs {
  url: string;
  serviceRoleKey: string;
}

/**
 * Service-role Supabase client. Bypasses RLS — server-side only.
 *
 * Guardrails:
 *   - Throws if it detects it's running in a browser (`window` defined).
 *   - Throws if the env var is missing.
 *
 * Use in:
 *   - apps/admin server actions and route handlers
 *   - the PDF service (Phase 6+)
 *   - never anywhere a client can reach.
 */
export function createServiceRoleSupabase({ url, serviceRoleKey }: CreateServiceRoleSupabaseArgs) {
  if (typeof window !== 'undefined') {
    throw new Error(
      '[GastroVoyage] createServiceRoleSupabase() was called in the browser. ' +
        'This client bypasses RLS and must NEVER be exposed to client code.',
    );
  }
  if (!url || !serviceRoleKey) {
    throw new Error(
      '[GastroVoyage] Missing SUPABASE_SERVICE_ROLE_KEY. Check apps/admin/.env.local.',
    );
  }

  return createClient<Database>(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

export type SupabaseServiceRole = ReturnType<typeof createServiceRoleSupabase>;
