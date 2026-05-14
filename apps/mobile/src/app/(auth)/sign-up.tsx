import { useState } from 'react';
import { View, Text, TextInput, Pressable, KeyboardAvoidingView, Platform } from 'react-native';
import { Link } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { useAuth } from '../../providers/AuthProvider';

export default function SignUp() {
  const { signUp } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const submit = async () => {
    setLoading(true);
    setError(null);
    setInfo(null);
    const { error } = await signUp(email.trim(), password, name.trim());
    setLoading(false);
    if (error) setError(error.message);
    else setInfo('Check your email to confirm your account, then sign in.');
  };

  return (
    <SafeAreaView className="flex-1 bg-parchment-50">
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        className="flex-1 justify-center px-6"
      >
        <View className="mb-8 items-center">
          <Text className="text-4xl text-navy-900 font-heading">Begin your journey</Text>
        </View>

        <Card>
          <Text className="text-navy-800 font-bodyMed mb-1.5">Display name</Text>
          <TextInput
            value={name}
            onChangeText={setName}
            placeholder="Vusal"
            placeholderTextColor="#7b6232"
            className="bg-parchment-100 border border-parchment-400 rounded-xl px-4 py-3 text-navy-900 font-body mb-4"
          />

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
            value={password}
            onChangeText={setPassword}
            placeholder="At least 6 characters"
            placeholderTextColor="#7b6232"
            className="bg-parchment-100 border border-parchment-400 rounded-xl px-4 py-3 text-navy-900 font-body"
          />

          {error ? (
            <Text className="text-burgundy-500 font-body text-sm mt-3">{error}</Text>
          ) : null}
          {info ? (
            <Text className="text-navy-800 font-body text-sm mt-3">{info}</Text>
          ) : null}

          <View className="mt-6">
            <Button
              label={loading ? 'Creating account...' : 'Create account'}
              onPress={submit}
              loading={loading}
              fullWidth
            />
          </View>

          <View className="flex-row justify-center mt-6">
            <Text className="text-navy-700 font-body">Already have an account? </Text>
            <Link href="/(auth)/sign-in" asChild>
              <Pressable>
                <Text className="text-navy-900 font-bodyBold underline">Sign in</Text>
              </Pressable>
            </Link>
          </View>
        </Card>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
