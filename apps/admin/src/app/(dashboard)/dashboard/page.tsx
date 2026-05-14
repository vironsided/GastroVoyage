import { createSupabaseServer } from '@/lib/supabase/server';
import { TOTAL_COUNTRIES } from '@gastrovoyage/shared';

export const dynamic = 'force-dynamic';

export default async function DashboardOverview() {
  const supabase = createSupabaseServer();

  const [{ count: countriesCount }, { count: restaurantsCount }, { count: partnersCount }, { count: visitsCount }] =
    await Promise.all([
      supabase.from('countries').select('*', { count: 'exact', head: true }),
      supabase.from('restaurants').select('*', { count: 'exact', head: true }),
      supabase
        .from('restaurants')
        .select('*', { count: 'exact', head: true })
        .eq('is_partner', true),
      supabase.from('visits').select('*', { count: 'exact', head: true }),
    ]);

  const stats = [
    { label: 'Countries seeded', value: countriesCount ?? '—', sub: `of ${TOTAL_COUNTRIES} target` },
    { label: 'Restaurants', value: restaurantsCount ?? 0, sub: 'in catalog' },
    { label: 'Partners', value: partnersCount ?? 0, sub: 'with active commission' },
    { label: 'Visits logged', value: visitsCount ?? 0, sub: 'across all users' },
  ];

  return (
    <div>
      <h2 className="font-heading text-4xl text-navy-900">Overview</h2>
      <p className="text-navy-700 mt-1 mb-8">A quick health check of the GastroVoyage data.</p>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((s) => (
          <div
            key={s.label}
            className="rounded-2xl border border-parchment-300 bg-paper p-6 shadow-sm"
          >
            <p className="text-xs uppercase tracking-widest text-navy-700">{s.label}</p>
            <p className="mt-2 font-heading text-4xl text-navy-900">{s.value}</p>
            <p className="text-xs text-navy-700 mt-1">{s.sub}</p>
          </div>
        ))}
      </div>

      <div className="mt-10 rounded-2xl border border-parchment-300 bg-paper p-6">
        <h3 className="font-heading text-2xl text-navy-900 mb-2">Phase 1</h3>
        <p className="text-navy-700 text-sm leading-relaxed">
          This is the project skeleton. Restaurant CRUD, partner toggles, and analytics charts land
          in Phase 6. For now you can verify connectivity, RLS, and the seed data via the read-only
          counters above.
        </p>
      </div>
    </div>
  );
}
