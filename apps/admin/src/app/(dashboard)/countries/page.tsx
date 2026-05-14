import { createSupabaseServer } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function CountriesPage() {
  const supabase = createSupabaseServer();
  const { data, error } = await supabase
    .from('countries')
    .select('iso_a2, name, region, subregion, flag_emoji')
    .order('name', { ascending: true })
    .limit(50);

  return (
    <div>
      <h2 className="font-heading text-4xl text-navy-900">Countries</h2>
      <p className="text-navy-700 mt-1 mb-6">
        Read-only in Phase 1. CRUD form arrives in Phase 3. Showing first 50 alphabetically.
      </p>

      {error ? (
        <div className="rounded-xl bg-burgundy-50 border border-burgundy-300 text-burgundy-700 px-4 py-3 text-sm">
          Failed to load countries: {error.message}
        </div>
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-parchment-300 bg-paper">
          <table className="w-full text-sm">
            <thead className="bg-parchment-100 text-navy-800 text-left">
              <tr>
                <th className="px-4 py-3 font-medium">Flag</th>
                <th className="px-4 py-3 font-medium">ISO</th>
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Region</th>
                <th className="px-4 py-3 font-medium">Subregion</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((c) => (
                <tr key={c.iso_a2} className="border-t border-parchment-200">
                  <td className="px-4 py-2 text-xl">{c.flag_emoji}</td>
                  <td className="px-4 py-2 font-mono text-xs text-navy-700">{c.iso_a2}</td>
                  <td className="px-4 py-2 text-navy-900">{c.name}</td>
                  <td className="px-4 py-2 text-navy-700">{c.region}</td>
                  <td className="px-4 py-2 text-navy-700">{c.subregion ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
