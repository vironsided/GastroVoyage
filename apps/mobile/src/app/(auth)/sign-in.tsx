import { useState } from 'react';
import { View, Text, TextInput, Pressable, KeyboardAvoidingView, Platform } from 'react-native';
import { Link } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { useAuth } from '../../providers/AuthProvider';

export default function SignIn() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('vusal@gastrovoyage.dev');
  const [password, setPassword] = useState('gastrovoyage');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setLoading(true);
    setError(null);
    const { error } = await signIn(email.trim(), password);
    setLoading(false);
    if (error) setError(error.message);
  };

  return (
    <SafeAreaView className="flex-1 bg-parchment-50">
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        className="flex-1 justify-center px-6"
      >
        <View className="mb-10 items-center">
          <Text className="text-5xl text-navy-900 font-heading">GastroVoyage</Text>
          <Text className="mt-2 text-navy-700 font-body text-base tracking-wider">
            taste the world, one country at a time
          </Text>
        </View>

        <Card>
          <Text className="text-2xl text-navy-900 font-heading mb-1">Welcome back</Text>
          <Text className="text-navy-700 font-body mb-6">
            Sign in to continue your culinary journey.
          </Text>

          <Text className="text-navy-800 font-bodyMed mb-1.5">Email</Text>
          <TextInput
            autoCapitalize="none"
            autoComplete="email"
            keyboardType="email-address"
            value={email}
            onChangeText={setEmail}
            placeholder="you@example.com"
            placeholderTextColor="#7b6232"
            className="bg-parchment-100 border border-parchment-400 rounded-xl px-4 py-3 text-navy-900 font-body mb-4"
          />

          <Text className="text-navy-800 font-bodyMed mb-1.5">Password</Text>
          <TextInput
            secureTextEntry
            autoComplete="password"
            value={password}
            onChangeText={setPassword}
            placeholder="••••••••"
            placeholderTextColor="#7b6232"
            className="bg-parchment-100 border border-parchment-400 rounded-xl px-4 py-3 text-navy-900 font-body mb-2"
          />

          {error ? (
            <Text className="text-burgundy-500 font-body text-sm mt-2">{error}</Text>
          ) : null}

          <View className="mt-6">
            <Button label={loading ? 'Signing in...' : 'Sign in'} onPress={submit} loading={loading} fullWidth />
          </View>

          <View className="flex-row justify-center mt-6">
            <Text className="text-navy-700 font-body">New here? </Text>
            <Link href="/(auth)/sign-up" asChild>
              <Pressable>
                <Text className="text-navy-900 font-bodyBold underline">Create an account</Text>
              </Pressable>
            </Link>
          </View>
        </Card>

        <Text className="text-center text-navy-700 font-body text-xs mt-8">
          Dev login pre-filled — see seed data in supabase/migrations.
        </Text>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
