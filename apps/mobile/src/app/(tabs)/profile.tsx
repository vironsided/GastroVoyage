import { View, Text, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { useAuth } from '../../providers/AuthProvider';

export default function ProfileScreen() {
  const { user, signOut } = useAuth();

  return (
    <SafeAreaView className="flex-1 bg-parchment-50">
      <ScrollView contentContainerStyle={{ padding: 20 }}>
        <Text className="text-4xl text-navy-900 font-heading">Profile</Text>
        <Text className="text-navy-700 font-body mt-1 mb-6">
          {user?.email ?? 'Not signed in'}
        </Text>

        <Card>
          <Text className="text-navy-900 font-heading text-xl mb-1">
            {user?.user_metadata?.display_name ?? 'Traveler'}
          </Text>
          <Text className="text-navy-700 font-body text-sm mb-4">User id: {user?.id ?? '—'}</Text>

          <View className="border-t border-parchment-300 pt-4">
            <Button label="Sign out" variant="secondary" onPress={signOut} fullWidth />
          </View>
        </Card>

        <Card className="mt-4">
          <Text className="text-navy-900 font-heading text-lg mb-1">Coming soon</Text>
          <Text className="text-navy-700 font-body">
            Edit display name and avatar (Phase 2), generate your printable map poster (Phase 6).
          </Text>
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}
