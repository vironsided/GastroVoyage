'use client';

import { useRouter } from 'next/navigation';
import { createBrowserClient } from '@supabase/ssr';
import type { Database } from '@gastrovoyage/shared';

export function SignOutButton() {
  const router = useRouter();
  return (
    <button
      onClick={async () => {
        const supabase = createBrowserClient<Database>(
          process.env.NEXT_PUBLIC_SUPABASE_URL!,
          process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        );
        await supabase.auth.signOut();
        router.push('/login');
        router.refresh();
      }}
      className="mt-3 w-full rounded-lg border border-parchment-400 bg-parchment-100 px-3 py-1.5 text-xs font-medium text-navy-800 hover:bg-parchment-200 transition"
    >
      Sign out
    </button>
  );
}
