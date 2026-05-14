import { Link } from 'expo-router';
import { Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function NotFound() {
  return (
    <SafeAreaView className="flex-1 bg-parchment-50">
      <View className="flex-1 items-center justify-center p-6">
        <Text className="text-6xl mb-4">🧭</Text>
        <Text className="text-3xl text-navy-900 font-heading mb-2">Off the map</Text>
        <Text className="text-navy-700 font-body text-center mb-6">
          That route doesn't exist in this world.
        </Text>
        <Link href="/(tabs)" className="text-navy-900 font-bodyBold underline">
          Return home
        </Link>
      </View>
    </SafeAreaView>
  );
}
