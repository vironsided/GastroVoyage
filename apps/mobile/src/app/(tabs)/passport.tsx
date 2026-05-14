import { useEffect, useState } from 'react';
import { View, Text, ScrollView, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card } from '../../components/ui/Card';
import { useAuth } from '../../providers/AuthProvider';
import { supabase } from '../../lib/supabase';
import { TOTAL_COUNTRIES } from '@gastrovoyage/shared';

interface VisitWithCountry {
  visited_on: string;
  rating: number | null;
  countries: { name: string; flag_emoji: string; region: string } | null;
}

export default function PassportScreen() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [visits, setVisits] = useState<VisitWithCountry[]>([]);

  useEffect(() => {
    if (!user) return;
    let active = true;
    (async () => {
      const { data, error } = await supabase
        .from('visits')
        .select('visited_on, rating, countries(name, flag_emoji, region)')
        .eq('user_id', user.id)
        .order('visited_on', { ascending: false });
      if (!active) return;
      if (error) {
        console.error('[passport] failed to load visits', error);
      } else {
        setVisits((data ?? []) as unknown as VisitWithCountry[]);
      }
      setLoading(false);
    })();
    return () => {
      active = false;
    };
  }, [user]);

  const count = visits.length;
  const pct = Math.min(100, Math.round((count / TOTAL_COUNTRIES) * 100));

  return (
    <SafeAreaView className="flex-1 bg-parchment-50">
      <ScrollView contentContainerStyle={{ padding: 20 }}>
        <Text className="text-4xl text-navy-900 font-heading">Your Passport</Text>
        <Text className="text-navy-700 font-body mt-1 mb-6">
          {count} of {TOTAL_COUNTRIES} cuisines explored
        </Text>

        <Card className="mb-6">
          <View className="flex-row justify-between items-end mb-2">
            <Text className="text-navy-900 font-heading text-3xl">{count}</Text>
            <Text className="text-navy-700 font-bodyMed">{pct}% complete</Text>
          </View>
          <View className="h-3 bg-parchment-200 rounded-full overflow-hidden">
            <View
              className="h-full bg-navy-800 rounded-full"
              style={{ width: `${pct}%` }}
            />
          </View>
        </Card>

        <Text className="text-navy-900 font-heading text-2xl mb-3">Recent stamps</Text>

        {loading ? (
          <ActivityIndicator color="#0d172b" />
        ) : visits.length === 0 ? (
          <Card>
            <Text className="text-navy-700 font-body">
              No stamps yet. Once Phase 5 lands, you'll be able to snap an Instax for each country.
            </Text>
          </Card>
        ) : (
          <View className="gap-3">
            {visits.map((v, i) => (
              <Card key={i} className="flex-row items-center">
                <Text className="text-3xl mr-3">{v.countries?.flag_emoji ?? '🏳️'}</Text>
                <View className="flex-1">
                  <Text className="text-navy-900 font-heading text-lg">
                    {v.countries?.name ?? 'Unknown'}
                  </Text>
                  <Text className="text-navy-700 font-body text-xs">
                    {v.countries?.region} • {v.visited_on}
                  </Text>
                </View>
                <Text className="text-brass-500 font-bodyBold text-base">
                  {v.rating ? '★'.repeat(v.rating) : ''}
                </Text>
              </Card>
            ))}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
