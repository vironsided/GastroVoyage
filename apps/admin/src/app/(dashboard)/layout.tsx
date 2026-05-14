import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServer } from '@/lib/supabase/server';
import { SignOutButton } from './SignOutButton';

const NAV = [
  { href: '/dashboard', label: 'Overview' },
  { href: '/countries', label: 'Countries' },
  { href: '/restaurants', label: 'Restaurants' },
  { href: '/analytics', label: 'Analytics' },
] as const;

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = createSupabaseServer();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login');
  }

  const isAdmin = (user.app_metadata as { role?: string } | null)?.role === 'admin';

  return (
    <div className="min-h-screen flex">
      <aside className="w-64 shrink-0 border-r border-parchment-300 bg-paper p-6 flex flex-col">
        <div className="mb-10">
          <h1 className="font-heading text-2xl text-navy-900 leading-tight">GastroVoyage</h1>
          <p className="text-xs uppercase tracking-widest text-navy-700">admin</p>
        </div>

        <nav className="flex-1 flex flex-col gap-1">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-lg px-3 py-2 text-navy-800 hover:bg-parchment-200 transition"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="mt-6 border-t border-parchment-300 pt-4 text-xs text-navy-700">
          <p className="font-medium text-navy-900 break-all">{user.email}</p>
          <p className="mt-0.5">{isAdmin ? 'Admin' : 'Awaiting admin role'}</p>
          <SignOutButton />
        </div>
      </aside>

      <main className="flex-1 p-8 overflow-x-auto">
        {!isAdmin ? (
          <div className="rounded-xl border border-burgundy-300 bg-burgundy-50 p-4 mb-6 text-burgundy-700 text-sm">
            Your account is signed in but doesn&apos;t have{' '}
            <code>app_metadata.role = &apos;admin&apos;</code> yet. Reads will be limited by RLS.
            See{' '}
            <code className="font-mono">docs/setup-supabase.md</code> step 7.
          </div>
        ) : null}
        {children}
      </main>
    </div>
  );
}
