'use client';

import { useFormStatus } from 'react-dom';
import { useSearchParams } from 'next/navigation';

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="w-full rounded-xl bg-navy-800 px-4 py-3 font-bodyBold text-parchment-50 transition hover:bg-navy-700 disabled:opacity-50"
    >
      {pending ? 'Signing in…' : 'Sign in'}
    </button>
  );
}

export function LoginForm({ action }: { action: (fd: FormData) => Promise<void> }) {
  const params = useSearchParams();
  const error = params.get('error');

  return (
    <form action={action} className="space-y-4">
      <label className="block">
        <span className="block text-sm font-medium text-navy-800 mb-1.5">Email</span>
        <input
          type="email"
          name="email"
          autoComplete="email"
          required
          className="w-full rounded-xl border border-parchment-400 bg-parchment-100 px-4 py-3 text-navy-900 focus:outline-none focus:ring-2 focus:ring-navy-700"
          placeholder="you@example.com"
        />
      </label>

      <label className="block">
        <span className="block text-sm font-medium text-navy-800 mb-1.5">Password</span>
        <input
          type="password"
          name="password"
          autoComplete="current-password"
          required
          className="w-full rounded-xl border border-parchment-400 bg-parchment-100 px-4 py-3 text-navy-900 focus:outline-none focus:ring-2 focus:ring-navy-700"
        />
      </label>

      {error ? <p className="text-sm text-burgundy-500">{error}</p> : null}

      <SubmitButton />
    </form>
  );
}
