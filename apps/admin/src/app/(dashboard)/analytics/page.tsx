import { createSupabaseServer } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function AnalyticsPage() {
  const supabase = createSupabaseServer();
  const { count: checkInsThisMonth } = await supabase
    .from('check_ins')
    .select('*', { count: 'exact', head: true })
    .gte('checked_in_at', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString());

  return (
    <div>
      <h2 className="font-heading text-4xl text-navy-900">Analytics</h2>
      <p className="text-navy-700 mt-1 mb-6">
        B2B commission reporting. Partner-level breakdowns and time-series charts arrive in Phase 6.
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-2xl border border-parchment-300 bg-paper p-6">
          <p className="text-xs uppercase tracking-widest text-navy-700">Check-ins this month</p>
          <p className="mt-2 font-heading text-4xl text-navy-900">{checkInsThisMonth ?? 0}</p>
          <p className="text-xs text-navy-700 mt-1">GPS-verified partner visits</p>
        </div>
      </div>

      <div className="mt-10 rounded-2xl border border-dashed border-parchment-400 bg-paper p-10 text-center">
        <p className="text-4xl mb-2">📊</p>
        <p className="text-navy-900 font-heading text-xl">Charts coming in Phase 6</p>
        <p className="text-navy-700 text-sm mt-1 max-w-md mx-auto">
          Top partner restaurants, commission breakdowns, and check-in heatmaps will live here.
        </p>
      </div>
    </div>
  );
}
