import { createSupabaseServer } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function RestaurantsPage() {
  const supabase = createSupabaseServer();
  const { data, error } = await supabase
    .from('restaurants')
    .select('id, name, city, is_partner, commission_rate, countries(name, flag_emoji)')
    .order('created_at', { ascending: false });

  return (
    <div>
      <h2 className="font-heading text-4xl text-navy-900">Restaurants</h2>
      <p className="text-navy-700 mt-1 mb-6">
        Add partner restaurants and set commission rates. CRUD form lands in Phase 6.
      </p>

      {error ? (
        <div className="rounded-xl bg-burgundy-50 border border-burgundy-300 text-burgundy-700 px-4 py-3 text-sm">
          Failed to load: {error.message}
        </div>
      ) : (data?.length ?? 0) === 0 ? (
        <div className="rounded-2xl border border-dashed border-parchment-400 bg-paper p-10 text-center">
          <p className="text-3xl mb-2">🍽️</p>
          <p className="text-navy-900 font-heading text-xl">No restaurants yet</p>
          <p className="text-navy-700 text-sm mt-1">
            Once Phase 6 ships the CRUD form, partners you add here will appear in the mobile
            app&apos;s country modals.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-parchment-300 bg-paper">
          <table className="w-full text-sm">
            <thead className="bg-parchment-100 text-navy-800 text-left">
              <tr>
                <th className="px-4 py-3 font-medium">Country</th>
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">City</th>
                <th className="px-4 py-3 font-medium">Partner</th>
                <th className="px-4 py-3 font-medium">Commission</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((r) => {
                const c = r.countries as { name: string; flag_emoji: string } | null;
                return (
                  <tr key={r.id} className="border-t border-parchment-200">
                    <td className="px-4 py-2 text-xl">{c?.flag_emoji ?? '🏳️'}</td>
                    <td className="px-4 py-2 text-navy-900">{r.name}</td>
                    <td className="px-4 py-2 text-navy-700">{r.city}</td>
                    <td className="px-4 py-2">
                      {r.is_partner ? (
                        <span className="rounded-full bg-brass-300 text-brass-900 px-2 py-0.5 text-xs font-bodyBold">
                          PARTNER
                        </span>
                      ) : (
                        <span className="text-navy-700 text-xs">—</span>
                      )}
                    </td>
                    <td className="px-4 py-2 text-navy-700">
                      {r.commission_rate != null ? `${r.commission_rate}%` : '—'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
