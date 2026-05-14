import { redirect } from 'next/navigation';
import { createSupabaseServer } from '@/lib/supabase/server';
import { LoginForm } from './LoginForm';

export const dynamic = 'force-dynamic';

export default async function LoginPage({
  searchParams,
}: {
  searchParams: { redirect?: string };
}) {
  async function signIn(formData: FormData) {
    'use server';
    const email = String(formData.get('email') ?? '');
    const password = String(formData.get('password') ?? '');
    const supabase = createSupabaseServer();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      redirect(`/login?error=${encodeURIComponent(error.message)}`);
    }
    redirect(searchParams.redirect ?? '/dashboard');
  }

  return (
    <main className="min-h-screen flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <h1 className="text-5xl font-heading text-navy-900">GastroVoyage</h1>
          <p className="mt-2 text-navy-700 tracking-wider text-sm">admin panel</p>
        </div>

        <div className="rounded-2xl border border-parchment-300 bg-paper p-8 shadow-md shadow-navy-900/10">
          <h2 className="font-heading text-2xl text-navy-900 mb-1">Sign in</h2>
          <p className="text-navy-700 text-sm mb-6">
            You must have{' '}
            <code className="font-mono text-xs">
              app_metadata.role = &apos;admin&apos;
            </code>{' '}
            to access the dashboard.
          </p>
          <LoginForm action={signIn} />
        </div>
      </div>
    </main>
  );
}
