import 'server-only';
import { createServiceRoleSupabase } from '@gastrovoyage/shared';

let cached: ReturnType<typeof createServiceRoleSupabase> | null = null;

/**
 * Service-role Supabase client (server-only).
 * Use in server actions, route handlers, and cron jobs that need to bypass RLS.
 */
export function getSupabaseAdmin() {
  if (cached) return cached;
  cached = createServiceRoleSupabase({
    url: process.env.NEXT_PUBLIC_SUPABASE_URL!,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY!,
  });
  return cached;
}
