import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The redirect Supabase's OAuth flow lands back on after Google's consent
/// screen. Must match an intent-filter registered in AndroidManifest.xml
/// (and, when a real iOS build exists, the URL scheme in Info.plist) —
/// see docs/KNOWN_ISSUES.md.
const _oauthRedirectUrl = 'com.loop.app.loop_mobile://login-callback';

/// Sign in / sign up, combined into one screen with a mode toggle —
/// mirrors apps/web's (auth) group so the two platforms feel like the same
/// product without literally sharing code. Real Supabase Auth, not a mock:
/// email/password via signInWithPassword/signUp, plus "Continue with
/// Google" via the same browser-based PKCE flow apps/web uses.
///
/// This is LOOP's "Imperial Verdigris" reference screen — see
/// docs/DESIGN_SYSTEM.md. Every other screen inherits the shared token
/// system through AppTheme regardless, but this one carries the full
/// editorial treatment (monogram, serif wordmark, engraved divider,
/// restrained accent use) that the rest of the app is judged against.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignIn = true;
  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final client = ref.read(supabaseClientProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignIn) {
        await client.auth.signInWithPassword(email: email, password: password);
      } else {
        await client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _oauthRedirectUrl,
        );
      }
      // On success the router's redirect (keyed off authStateChangesProvider)
      // takes over — no manual navigation needed here.
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () => _error =
            'Something went wrong. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _googleSubmitting = true;
      _error = null;
    });

    final client = ref.read(supabaseClientProvider);
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () => _error =
            'Could not open Google sign-in. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _googleSubmitting = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignIn = !_isSignIn;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _submitting || _googleSubmitting;

    return Scaffold(
      body: Stack(
        children: [
          // Barely-visible mineral bloom — noticed subconsciously, not
          // seen as a decoration. No blur, no shader: a single cheap
          // RadialGradient well under the directive's 2-5% ceiling.
          const Positioned.fill(child: _VerdigrisBloom()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Center(child: _LoopSeal()),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'LOOP',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Earn. Buy. Own. Return or resell. Earn again.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        (_isSignIn ? 'Sign in' : 'Create your account')
                            .toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textStructural,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : _submitGoogle,
                          icon: _googleSubmitting
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const _GoogleGlyph(),
                          label: Text(
                            _googleSubmitting
                                ? 'Redirecting…'
                                : 'Continue with Google',
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.ledgerBlack,
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.royalPewter.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _EngravedDivider(),
                      const SizedBox(height: AppSpacing.lg),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              enabled: !busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (value) {
                                if (value == null || !value.contains('@')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !busy,
                              obscureText: true,
                              autofillHints: [
                                _isSignIn
                                    ? AutofillHints.password
                                    : AutofillHints.newPassword,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (value) {
                                if (value == null || value.length < 8) {
                                  return 'At least 8 characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) =>
                                  busy ? null : _submitEmailPassword(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.dangerText,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: busy ? null : _submitEmailPassword,
                                child: _submitting
                                    ? SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.onAccentFill,
                                        ),
                                      )
                                    : Text(_isSignIn ? 'Sign in' : 'Sign up'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: TextButton(
                          onPressed: busy ? null : _toggleMode,
                          child: Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                              children: [
                                TextSpan(
                                  text: _isSignIn
                                      ? "Don't have an account? "
                                      : 'Already have an account? ',
                                ),
                                TextSpan(
                                  text: _isSignIn ? 'Sign up' : 'Sign in',
                                  style: const TextStyle(
                                    color: AppColors.verdigrisText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple "G" mark in Google's brand blue. Deliberately not attempting a
/// pixel-perfect four-color logo reproduction via hand-parsed SVG path data
/// — that's real complexity and real bug surface for a decorative icon;
/// this reads clearly as "Google" without it.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// LOOP's small brand mark: two interlocking circles standing in for the
/// product's own name (a loop), not a crown or shield — "more intelligent
/// than a crown" per the design brief. Drawn, not imported, so it costs
/// nothing to ship and nothing to render (a handful of stroked arcs).
class _LoopSeal extends StatelessWidget {
  const _LoopSeal();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 28,
      child: CustomPaint(painter: _LoopSealPainter()),
    );
  }
}

class _LoopSealPainter extends CustomPainter {
  const _LoopSealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.verdigrisBright;
    final radius = size.height / 2 - 1;
    final leftCenter = Offset(size.width / 2 - radius * 0.55, size.height / 2);
    final rightCenter = Offset(size.width / 2 + radius * 0.55, size.height / 2);
    canvas.drawCircle(leftCenter, radius, paint);
    canvas.drawCircle(rightCenter, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A thin engraved rule with a centered "or" — replaces a plain
/// Divider()-on-both-sides row with something that reads as an
/// intentional archival detail rather than default Material chrome.
class _EngravedDivider extends StatelessWidget {
  const _EngravedDivider();

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 1,
      color: AppColors.blackenedSilver.withValues(alpha: 0.35),
    );
    return Row(
      children: [
        Expanded(child: line),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'or',
            style: GoogleFonts.inter(
              fontSize: 11,
              letterSpacing: 1.5,
              color: AppColors.mutedParchment,
            ),
          ),
        ),
        Expanded(child: line),
      ],
    );
  }
}

/// Extremely subtle radial Verdigris bloom behind the auth content —
/// noticed subconsciously, not as visible wallpaper. A single gradient
/// paint, no image asset, no blur filter.
class _VerdigrisBloom extends StatelessWidget {
  const _VerdigrisBloom();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.1,
          colors: [
            AppColors.verdigrisDark.withValues(alpha: 0.16),
            AppColors.obsidian.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
