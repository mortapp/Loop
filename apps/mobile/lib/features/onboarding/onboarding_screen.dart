import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/profile_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/loop_seal.dart';

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

enum _UsernameStatus { idle, invalid, checking, available, taken }

/// One-time onboarding step, reached only when the signed-in user has
/// never set a display name (see `needsOnboardingProvider` in
/// app_router.dart) — true for every brand-new account whether they
/// signed up with Google or email/password. An existing account with a
/// name already set never sees this screen; the router redirects past
/// it automatically.
///
/// Mirrors apps/web's /auth/complete-profile control-for-control: same
/// suggested-name/username logic, same live @username availability
/// check against `public.is_username_available`, same optional
/// password-linking step for a Google-only account (no email/password
/// identity yet) via `auth.updateUser` — never a second account, always
/// the same Supabase auth user id.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _debounce;
  bool _submitting = false;
  String? _error;

  bool get _offerPasswordSetup {
    final identities = ref
        .read(supabaseClientProvider)
        .auth
        .currentUser
        ?.identities;
    return identities == null || !identities.any((i) => i.provider == 'email');
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _suggestedName());
    _usernameController = TextEditingController(text: _suggestedUsername())
      ..addListener(_onUsernameChanged);
    _onUsernameChanged();
  }

  String _suggestedName() {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    final metadata = user?.userMetadata;
    final metaName =
        (metadata?['full_name'] as String?) ?? (metadata?['name'] as String?);
    if (metaName != null && metaName.trim().isNotEmpty) return metaName.trim();
    return _titleCaseFromEmail(_emailLocalPart());
  }

  String _suggestedUsername() {
    final cleaned = _emailLocalPart().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '',
    );
    final trimmed = cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
    return trimmed.length >= 3 ? trimmed : '';
  }

  String _emailLocalPart() {
    final email = ref.read(supabaseClientProvider).auth.currentUser?.email;
    return email?.split('@').first ?? '';
  }

  String _titleCaseFromEmail(String localPart) {
    if (localPart.isEmpty) return '';
    return localPart
        .split(RegExp(r'[._-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _onUsernameChanged() {
    _debounce?.cancel();
    final candidate = _usernameController.text.trim().toLowerCase();

    if (candidate.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (!_usernamePattern.hasMatch(candidate)) {
      setState(() => _usernameStatus = _UsernameStatus.invalid);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final client = ref.read(supabaseClientProvider);
        final available =
            await client.rpc(
                  'is_username_available',
                  params: {'candidate': candidate},
                )
                as bool;
        if (!mounted) return;
        if (_usernameController.text.trim().toLowerCase() != candidate) {
          return; // input changed again while this check was in flight
        }
        setState(
          () => _usernameStatus = available
              ? _UsernameStatus.available
              : _UsernameStatus.taken,
        );
      } catch (_) {
        if (mounted) setState(() => _usernameStatus = _UsernameStatus.idle);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (username.isEmpty) {
      setState(() => _error = 'Choose a username.');
      return;
    }
    if (!_usernamePattern.hasMatch(username)) {
      setState(
        () => _error =
            'Usernames are 3-20 characters: lowercase letters, numbers, and underscores only.',
      );
      return;
    }

    final offerPassword = _offerPasswordSetup;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (offerPassword && (password.isNotEmpty || confirmPassword.isNotEmpty)) {
      if (password.length < 8) {
        setState(() => _error = 'Password must be at least 8 characters.');
        return;
      }
      if (password != confirmPassword) {
        setState(() => _error = "Passwords don't match.");
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      if (offerPassword && password.isNotEmpty) {
        await client.auth.updateUser(UserAttributes(password: password));
      }

      await ref.read(profileRepositoryProvider).updateDisplayName(userId, name);
      await client
          .from('profiles')
          .update({'username': username})
          .eq('id', userId);

      ref.invalidate(currentProfileProvider);
      // needsOnboardingProvider flips false once currentProfileProvider
      // resolves with the new name, and the router redirects away on
      // its own — no manual navigation needed here.
    } on PostgrestException catch (e) {
      setState(
        () => _error = e.code == '23505'
            ? 'That username is already taken.'
            : e.code == '23514'
            ? "That username isn't allowed. Try a different one."
            : 'Something went wrong: ${e.message}',
      );
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LoopSeal(size: 32)),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Text(
                      '✓ Verified',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.tyrianText,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Welcome to LOOP',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Let's finish setting up your account.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel('EMAIL'),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: AppColors.platinum.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FieldLabel('NAME'),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    autofocus: true,
                    decoration: const InputDecoration(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FieldLabel('USERNAME'),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _usernameController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(prefixText: '@'),
                  ),
                  if (_usernameHint() != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _usernameHint()!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _usernameHintColor(),
                      ),
                    ),
                  ],
                  if (_offerPasswordSetup) ...[
                    const SizedBox(height: AppSpacing.md),
                    _FieldLabel(
                      'PASSWORD (optional — to also sign in without Google)',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _passwordController,
                      enabled: !_submitting,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FieldLabel('CONFIRM PASSWORD'),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _confirmPasswordController,
                      enabled: !_submitting,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(),
                    ),
                  ],
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
                        onPressed:
                            (_submitting ||
                                _usernameStatus == _UsernameStatus.taken ||
                                _usernameStatus == _UsernameStatus.invalid)
                            ? null
                            : _submit,
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
                            : const Text('Finish setup'),
                      ),
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

  String? _usernameHint() {
    switch (_usernameStatus) {
      case _UsernameStatus.idle:
        return null;
      case _UsernameStatus.invalid:
        return '3-20 characters: lowercase letters, numbers, underscores';
      case _UsernameStatus.checking:
        return 'Checking…';
      case _UsernameStatus.available:
        return 'Available';
      case _UsernameStatus.taken:
        return 'Already taken';
    }
  }

  Color _usernameHintColor() {
    switch (_usernameStatus) {
      case _UsernameStatus.available:
        return AppColors.tyrianText;
      case _UsernameStatus.invalid:
      case _UsernameStatus.taken:
        return AppColors.dangerText;
      case _UsernameStatus.idle:
      case _UsernameStatus.checking:
        return AppColors.textMuted;
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.textStructural,
        letterSpacing: 1.5,
        fontSize: 10.5,
      ),
    );
  }
}
