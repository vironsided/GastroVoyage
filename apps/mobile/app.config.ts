import type { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  name: 'GastroVoyage',
  slug: 'gastrovoyage',
  scheme: 'gastrovoyage',
  version: '0.1.0',
  orientation: 'portrait',
  userInterfaceStyle: 'light',
  newArchEnabled: true,
  ios: {
    supportsTablet: true,
    bundleIdentifier: 'com.gastrovoyage.app',
  },
  android: {
    package: 'com.gastrovoyage.app',
  },
  web: {
    bundler: 'metro',
  },
  plugins: ['expo-router'],
  experiments: {
    typedRoutes: true,
  },
  extra: {
    router: {
      origin: false,
    },
  },
};

export default config;
