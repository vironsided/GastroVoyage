import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/oauth_config.dart';

// ─── Particle data ────────────────────────────────────────────────────────────

class _Particle {
  const _Particle({
    required this.icon,
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.swayAmp,
  });

  final IconData icon;
  final double x;        // 0.0–1.0 relative to screen width
  final double phase;    // initial phase offset in radians
  final double speed;    // vertical drift speed multiplier
  final double size;     // icon size
  final double swayAmp;  // horizontal sway amplitude (px)
}

// ─── Login Screen ─────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isSignIn = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _pendingVerificationEmail;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _particleCtrl;
  late final AnimationController _formAnimCtrl;
  late final AnimationController _logoAnimCtrl;
  late final AnimationController _buttonPressCtrl;

  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _buttonScale;

  late final List<_Particle> _particles;

  static const _icons = [
    LucideIcons.utensils, LucideIcons.coffee, LucideIcons.star,
    LucideIcons.heart,    LucideIcons.leaf,   LucideIcons.compass,
    LucideIcons.globe,    LucideIcons.award,  LucideIcons.flame,
    LucideIcons.map,      LucideIcons.flag,   LucideIcons.zap,
    LucideIcons.crown,    LucideIcons.bookmark,
  ];

  @override
  void initState() {
    super.initState();

    final rand = math.Random(7);
    _particles = List.generate(14, (i) => _Particle(
      icon: _icons[i % _icons.length],
      x: rand.nextDouble(),
      phase: rand.nextDouble() * 2 * math.pi,
      speed: 0.35 + rand.nextDouble() * 0.55,
      size: 18.0 + rand.nextDouble() * 20.0,
      swayAmp: 18.0 + rand.nextDouble() * 28.0,
    ));

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _logoAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimCtrl, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(parent: _logoAnimCtrl, curve: Curves.easeOut);

    _formAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _formFade = CurvedAnimation(parent: _formAnimCtrl, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formAnimCtrl, curve: Curves.easeOutCubic));

    _buttonPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _buttonScale = _buttonPressCtrl;

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _logoAnimCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _formAnimCtrl.forward();
    });
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _formAnimCtrl.dispose();
    _logoAnimCtrl.dispose();
    _buttonPressCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _switchTab(bool signIn) {
    if (_isSignIn == signIn) return;
    setState(() {
      _isSignIn = signIn;
      _errorMessage = null;
    });
  }

  String _parseDioError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Cannot connect to server. Check your connection.';
      }
      final status = e.response?.statusCode;
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail'] as String?
          : null;
      if (status == 401) return 'Invalid email or password.';
      if (status == 403) return 'Email not confirmed yet. Click the link in your inbox.';
      if (status == 409) return detail ?? 'An account with this email already exists. Please sign in.';
      if (status == 422) return detail ?? 'Invalid input. Check your details.';
      return detail ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _buttonPressCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 100));
    _buttonPressCtrl.forward();

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      final api = ref.read(apiClientProvider);

      if (_isSignIn) {
        final result = await api.signIn(email: email, password: password);
        if (!mounted) return;
        await ref.read(authProvider.notifier).setAuthenticated(
          userId: result.userId,
          email: result.email,
          displayName: result.displayName,
          homeCity: result.homeCity,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          isEmailVerified: result.emailConfirmed,
        );
      } else {
        final name = _nameCtrl.text.trim();
        final result = await api.signUp(
          email: email,
          password: password,
          displayName: name,
        );
        if (!mounted) return;

        if (!result.emailConfirmed) {
          setState(() {
            _isLoading = false;
            _pendingVerificationEmail = result.email;
          });
          return;
        }

        await ref.read(authProvider.notifier).setAuthenticated(
          userId: result.userId,
          email: result.email,
          displayName: result.displayName,
          homeCity: result.homeCity,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          isEmailVerified: true,
        );
        if (mounted) await ref.read(gastroThemeProvider.notifier).reset();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _parseDioError(e);
      });
      return;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkVerification() async {
    final email = _pendingVerificationEmail!;
    final password = _passwordCtrl.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.signIn(email: email, password: password);
      if (!mounted) return;

      if (!result.emailConfirmed) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Email not confirmed yet. Please click the link in your inbox.';
        });
        return;
      }

      await ref.read(authProvider.notifier).setAuthenticated(
        userId: result.userId,
        email: result.email,
        displayName: result.displayName,
        homeCity: result.homeCity,
        accessToken: result.accessToken,
        isEmailVerified: true,
      );
      if (mounted) await ref.read(gastroThemeProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      String msg = _parseDioError(e);
      if (e is DioException && e.response?.statusCode == 403) {
        msg = 'Email not confirmed yet. Please click the link in your inbox.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  Future<void> _resendVerification() async {
    final email = _pendingVerificationEmail!;
    try {
      await ref.read(apiClientProvider).resendVerification(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification email resent to $email',
              style: GoogleFonts.hankenGrotesk(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // best-effort — never reveal if email exists
    }
  }

  // ── OAuth (Google / Apple) ─────────────────────────────────────────────────

  /// Completes an OAuth sign-in once the [AuthResult] is back from the
  /// backend: persists the session exactly like the email path and resets
  /// the theme so the gating in `main.dart` routes the user into the app.
  Future<void> _completeOAuth(AuthResult result) async {
    if (!mounted) return;
    await ref.read(authProvider.notifier).setAuthenticated(
          userId: result.userId,
          email: result.email,
          displayName: result.displayName,
          homeCity: result.homeCity,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          isEmailVerified: result.emailConfirmed,
        );
    if (mounted) await ref.read(gastroThemeProvider.notifier).reset();
  }

  Future<void> _signInWithGoogle() async {
    if (!OAuthConfig.isGoogleConfigured) {
      setState(() => _errorMessage = "Google sign-in isn't configured yet.");
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: OAuthConfig.googleWebClientId,
        clientId: OAuthConfig.googleIosClientId.isNotEmpty
            ? OAuthConfig.googleIosClientId
            : null,
      );
      // Always start from a clean slate so the account picker shows.
      await googleSignIn.signOut();

      final account = await googleSignIn.signIn();
      if (account == null) {
        // User dismissed the account picker — not an error.
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Google did not return a sign-in token. Please try again.';
          });
        }
        return;
      }

      final api = ref.read(apiClientProvider);
      final result = await api.oauthSignIn(
        provider: 'google',
        idToken: idToken,
        accessToken: auth.accessToken,
        displayName: account.displayName,
      );
      await _completeOAuth(result);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _parseOAuthError(e, 'Google');
      });
    }
  }

  Future<void> _signInWithApple() async {
    if (!OAuthConfig.isAppleConfigured) {
      setState(() => _errorMessage = "Apple sign-in isn't configured yet.");
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Required on Android (and web): Apple has no native SDK there, so
        // the flow runs through Apple's web auth page back to the Service
        // ID's registered redirect URI (the Supabase auth callback).
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: OAuthConfig.appleServiceId,
          redirectUri: Uri.parse(OAuthConfig.appleRedirectUri),
        ),
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Apple did not return a sign-in token. Please try again.';
          });
        }
        return;
      }

      // Apple only sends the name on the very first sign-in.
      final namePieces = [
        credential.givenName ?? '',
        credential.familyName ?? '',
      ].where((p) => p.isNotEmpty);
      final displayName = namePieces.join(' ').trim();

      final api = ref.read(apiClientProvider);
      final result = await api.oauthSignIn(
        provider: 'apple',
        idToken: idToken,
        accessToken: credential.authorizationCode,
        displayName: displayName.isEmpty ? null : displayName,
      );
      await _completeOAuth(result);
      if (mounted) setState(() => _isLoading = false);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      // canceled is a normal user action — silent, no error banner.
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == AuthorizationErrorCode.canceled
            ? null
            : 'Apple sign-in failed. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _parseOAuthError(e, 'Apple');
      });
    }
  }

  /// Maps an OAuth failure to a friendly, themed message. User cancellations
  /// resolve to `null` so no error banner is shown.
  String? _parseOAuthError(Object e, String provider) {
    final text = e.toString().toLowerCase();
    if (text.contains('cancel') || text.contains('aborted')) return null;
    if (e is DioException) return _parseDioError(e);
    if (text.contains('network') || text.contains('socket')) {
      return 'Cannot connect to server. Check your connection.';
    }
    return '$provider sign-in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(gastroThemeProvider) ?? GastroThemeMode.girls;
    final config = GastroThemeConfig.forMode(themeMode);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Floating food particles ──────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, _) {
              final t = _particleCtrl.value;
              return Stack(
                children: _particles.map((p) {
                  final progress = (t * p.speed + p.phase / (2 * math.pi)) % 1.0;
                  final y = (1.15 - progress * 1.3) * size.height;
                  final x = p.x * size.width +
                      math.sin(t * 2 * math.pi + p.phase) * p.swayAmp;

                  double opacity;
                  if (progress < 0.08) {
                    opacity = progress / 0.08;
                  } else if (progress > 0.75) {
                    opacity = (1.0 - progress) / 0.25;
                  } else {
                    opacity = 1.0;
                  }
                  opacity = (opacity * 0.28).clamp(0.0, 1.0);

                  return Positioned(
                    left: x - p.size / 2,
                    top: y - p.size / 2,
                    child: Transform.rotate(
                      angle: math.sin(t * math.pi * 1.5 + p.phase) * 0.4,
                      child: Opacity(
                        opacity: opacity,
                        child: Icon(
                          p.icon,
                          size: p.size,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ── Gradient overlay (bottom-heavy dark vignette) ─────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 52),
                    // Logo section
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: _buildLogo(config),
                      ),
                    ),
                    const SizedBox(height: 44),
                    // Form card (or verification pending card)
                    SlideTransition(
                      position: _formSlide,
                      child: FadeTransition(
                        opacity: _formFade,
                        child: _pendingVerificationEmail != null
                            ? _buildVerificationCard(config)
                            : _buildFormCard(config),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────

  Widget _buildLogo(GastroThemeConfig config) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                config.accent,
                config.accent.withOpacity(0.6),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: config.accent.withOpacity(0.45),
                blurRadius: 28,
                spreadRadius: 4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(LucideIcons.compass, size: 38, color: Colors.white),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'GASTRO',
          style: GoogleFonts.playfairDisplay(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
        Text(
          'VOYAGE',
          style: GoogleFonts.playfairDisplay(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: config.accent,
            letterSpacing: 5,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'your culinary passport',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white38,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  // ── Form card ──────────────────────────────────────────────────────────────

  Widget _buildFormCard(GastroThemeConfig config) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: config.accent.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: config.accent.withOpacity(0.08),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab switcher
            _buildTabSwitcher(config),
            const SizedBox(height: 28),

            // Animated name field (sign up only)
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: _isSignIn
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _GastroTextField(
                          controller: _nameCtrl,
                          label: 'Your name',
                          icon: Icons.person_outline_rounded,
                          config: config,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
            ),

            // Email
            _GastroTextField(
              controller: _emailCtrl,
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              config: config,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            _GastroTextField(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              config: config,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                if (!_isSignIn && v.length < 8) return 'At least 8 characters';
                return null;
              },
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFBA1A1A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBA1A1A).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF6B6B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 26),

            // Submit button
            ScaleTransition(
              scale: _buttonScale,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: _GastroButton(
                  label: _isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT',
                  isLoading: _isLoading,
                  config: config,
                  onPressed: _isLoading ? null : _submit,
                ),
              ),
            ),

            if (_isSignIn) ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            ],

            // ── "or" divider + social sign-in ─────────────────────────────
            SizedBox(height: _isSignIn ? 6 : 22),
            _buildOrDivider(),
            const SizedBox(height: 18),
            _OAuthButton(
              label: _isSignIn
                  ? 'Continue with Google'
                  : 'Sign up with Google',
              dark: false,
              icon: const _GoogleGlyph(),
              onPressed: _isLoading ? null : _signInWithGoogle,
            ),
            const SizedBox(height: 12),
            _OAuthButton(
              label: _isSignIn
                  ? 'Continue with Apple'
                  : 'Sign up with Apple',
              dark: true,
              icon: const Icon(Icons.apple, color: Colors.white, size: 22),
              onPressed: _isLoading ? null : _signInWithApple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              color: Colors.white38,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
        ),
      ],
    );
  }

  // ── Verification pending card ──────────────────────────────────────────────

  Widget _buildVerificationCard(GastroThemeConfig config) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: config.accent.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: config.accent.withOpacity(0.12),
            ),
            child: Icon(LucideIcons.mailCheck, size: 30, color: config.accent),
          ),
          const SizedBox(height: 20),
          Text(
            'Check your inbox',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We sent a verification link to',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _pendingVerificationEmail!,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: config.accent,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Click the link in that email, then tap the button below to enter the app.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFBA1A1A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFBA1A1A).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF6B6B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: _GastroButton(
              label: 'I CONFIRMED MY EMAIL',
              isLoading: _isLoading,
              config: config,
              onPressed: _isLoading ? null : _checkVerification,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _resendVerification,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Resend verification email',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: Colors.white38,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _pendingVerificationEmail = null;
              _errorMessage = null;
            }),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Back to sign in',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(GastroThemeConfig config) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabButton(
            label: 'Sign In',
            isActive: _isSignIn,
            config: config,
            onTap: () => _switchTab(true),
          ),
          _TabButton(
            label: 'Sign Up',
            isActive: !_isSignIn,
            config: config,
            onTap: () => _switchTab(false),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.config,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final GastroThemeConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? config.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: config.accent.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GastroTextField extends StatelessWidget {
  const _GastroTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.config,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final GastroThemeConfig config;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hankenGrotesk(
          color: Colors.white38,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1C1C1C),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.07), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: config.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFBA1A1A), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFFF6B6B), width: 1.5),
        ),
        errorStyle: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          color: const Color(0xFFFF6B6B),
        ),
      ),
    );
  }
}

class _GastroButton extends StatelessWidget {
  const _GastroButton({
    required this.label,
    required this.isLoading,
    required this.config,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final GastroThemeConfig config;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: onPressed != null
              ? [config.accent, config.accent.withOpacity(0.75)]
              : [
                  config.accent.withOpacity(0.4),
                  config.accent.withOpacity(0.3),
                ],
        ),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: config.accent.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.08),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A social sign-in button. [dark] flips between the Apple-style dark button
/// and the Google-style light button; both keep the rounded GastroVoyage
/// card geometry so they sit naturally below the email/password form.
class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.dark,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final bool dark;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final fg = dark ? Colors.white : const Color(0xFF1A1A1A);
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.black.withOpacity(0.06),
            highlightColor: Colors.black.withOpacity(0.04),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 22, height: 22, child: Center(child: icon)),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Google "G" mark, drawn so no asset/network image is needed.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleGlyphPainter(),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      w - stroke,
      h - stroke,
    );

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four coloured arcs around the ring.
    canvas.drawArc(rect, _deg(-45), _deg(-90), false, arc(_yellow));
    canvas.drawArc(rect, _deg(-135), _deg(-90), false, arc(_red));
    canvas.drawArc(rect, _deg(135), _deg(-90), false, arc(_blue));
    canvas.drawArc(rect, _deg(45), _deg(-90), false, arc(_green));

    // The horizontal bar of the "G".
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, h * 0.40, w * 0.5 - stroke / 2, stroke),
      barPaint,
    );
  }

  static double _deg(double d) => d * math.pi / 180.0;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
