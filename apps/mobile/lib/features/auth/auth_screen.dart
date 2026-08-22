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
/// This is LOOP's "Murex Noir" reference screen — see
/// docs/DESIGN_SYSTEM.md. Every other screen inherits the shared token
/// system through AppTheme regardless, but this one carries the full
/// editorial treatment (double loop seal, serif wordmark, engraved
/// divider, persistent micro-labels, restrained accent use) that the
/// rest of the app is judged against.
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
          // Felt, not seen: a single cheap RadialGradient wash plus one
          // faint oversized seal watermark. No blur, no shader — well
          // under the directive's 2-4% ceiling.
          const Positioned.fill(child: _MurexWash()),
          const Positioned(right: -60, top: 40, child: _SealWatermark()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Center(child: _LoopSeal()),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'LOOP',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PRIVATE VALUE LEDGER',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.champagne,
                          letterSpacing: 3,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Earn. Buy. Own. Return or resell. Earn again.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                            backgroundColor: AppColors.murexInk,
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.platinum.withValues(alpha: 0.22),
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
                            _LabeledField(
                              label: 'EMAIL',
                              child: TextFormField(
                                controller: _emailController,
                                enabled: !busy,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  hintText: 'you@business.com',
                                ),
                                validator: (value) {
                                  if (value == null || !value.contains('@')) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _LabeledField(
                              label: 'PASSWORD',
                              child: TextFormField(
                                controller: _passwordController,
                                enabled: !busy,
                                obscureText: true,
                                autofillHints: [
                                  _isSignIn
                                      ? AutofillHints.password
                                      : AutofillHints.newPassword,
                                ],
                                decoration: const InputDecoration(
                                  hintText: '••••••••',
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
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      AppColors.imperialPlum,
                                      AppColors.tyrianRoyal,
                                      AppColors.tyrianDeep,
                                    ],
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: busy ? null : _submitEmailPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                  ),
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
                                    color: AppColors.tyrianText,
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

/// A tiny persistent uppercase label above a bare (hint-only) field —
/// reads as a constructed financial form rather than default Material
/// floating-label chrome.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textStructural,
              letterSpacing: 1.5,
              fontSize: 10.5,
            ),
          ),
        ),
        child,
      ],
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

/// LOOP's brand mark: the "double loop seal" — two precisely interlocked
/// rings, each drawn with an engraved double line (outer Platinum, inner
/// Tyrian) and a tiny Champagne key point where they cross. Reads at once
/// as a banking seal, an archive stamp, and a monogram — deliberately not
/// a crown or shield. Drawn, not imported: a handful of stroked arcs,
/// nothing that costs anything to ship or render.
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
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.platinum.withValues(alpha: 0.85);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.tyrianAccent;
    final keyPoint = Paint()..color = AppColors.champagne;

    final radius = size.height / 2 - 1;
    final leftCenter = Offset(size.width / 2 - radius * 0.55, size.height / 2);
    final rightCenter = Offset(size.width / 2 + radius * 0.55, size.height / 2);

    canvas.drawCircle(leftCenter, radius, outer);
    canvas.drawCircle(rightCenter, radius, outer);
    canvas.drawCircle(leftCenter, radius - 3, inner);
    canvas.drawCircle(rightCenter, radius - 3, inner);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 1.1, keyPoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The same seal drawn at ~30x scale and ~3% opacity, offset off-canvas —
/// "felt, not seen" watermark per the directive. A single static paint,
/// no animation, no filter.
class _SealWatermark extends StatelessWidget {
  const _SealWatermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.035,
        child: SizedBox(
          width: 420,
          height: 300,
          child: CustomPaint(painter: _LoopSealPainter()),
        ),
      ),
    );
  }
}

/// A thin engraved rule with a centered archival diamond — replaces a
/// plain Divider()-on-both-sides row with something that reads as an
/// intentional archival detail rather than default Material chrome.
class _EngravedDivider extends StatelessWidget {
  const _EngravedDivider();

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 1,
      color: AppColors.smokedPlatinum.withValues(alpha: 0.3),
    );
    return Row(
      children: [
        Expanded(child: line),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            '◇',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.smokedPlatinum,
            ),
          ),
        ),
        Expanded(child: line),
      ],
    );
  }
}

/// Extremely subtle radial Murex wash behind the auth content — noticed
/// subconsciously, not seen as decoration. A single gradient paint, no
/// image asset, no blur filter.
class _MurexWash extends StatelessWidget {
  const _MurexWash();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.1,
          colors: [
            AppColors.imperialPlum.withValues(alpha: 0.18),
            AppColors.murexNoir.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
