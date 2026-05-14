import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createBrowserSupabase } from '@gastrovoyage/shared';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  console.error(
    '[GastroVoyage] Missing EXPO_PUBLIC_SUPABASE_URL or EXPO_PUBLIC_SUPABASE_ANON_KEY. ' +
      'Copy apps/mobile/.env.example to apps/mobile/.env.local and fill it in.',
  );
}

export const supabase = createBrowserSupabase({
  url: url ?? '',
  anonKey: anonKey ?? '',
  storage: AsyncStorage,
});
