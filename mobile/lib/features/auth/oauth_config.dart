/// OAuth provider configuration for native Google / Apple sign-in.
///
/// None of these values are secrets — they're public client identifiers — so
/// they're supplied at build time via `--dart-define` rather than hardcoded.
/// Until they're configured the values are empty strings and the relevant
/// `isXConfigured` getter returns `false`, which the login screen uses to show
/// a "not configured yet" message instead of crashing.
///
/// Build with, e.g.:
/// ```
/// flutter run \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=yyyyy.apps.googleusercontent.com \
///   --dart-define=APPLE_SERVICE_ID=app.gastrovoyage.signin \
///   --dart-define=APPLE_REDIRECT_URI=https://<project-ref>.supabase.co/auth/v1/callback
/// ```
class OAuthConfig {
  const OAuthConfig._();

  /// Google OAuth **Web** client ID. On Android & iOS this is passed to
  /// `google_sign_in` as the `serverClientId` so the SDK returns an ID token
  /// whose audience Supabase can verify. Required for Google sign-in.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Google OAuth **iOS** client ID. Optional — only needed on iOS builds; on
  /// Android the value from `google-services` / the web client is sufficient.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Apple **Service ID** (the "Sign in with Apple" identifier created in the
  /// Apple Developer portal). Used for the Android/web web-auth fallback flow.
  static const String appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: '',
  );

  /// The redirect URI registered for the Apple Service ID. For this app it is
  /// the Supabase auth callback: `https://<project-ref>.supabase.co/auth/v1/callback`.
  static const String appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: '',
  );

  /// True once a Google client ID has been supplied at build time.
  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;

  /// True once the Apple Service ID + redirect URI have been supplied. Both
  /// are needed for the Android web-auth flow; on iOS the native flow needs
  /// neither, but we still gate on this so behaviour is consistent and the
  /// user gets a clear message until the provider is set up.
  static bool get isAppleConfigured =>
      appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty;
}
