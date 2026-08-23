import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/profile_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/loop_seal.dart';

/// One-time onboarding step, reached only when the signed-in user has
/// never set a display name (see `needsOnboardingProvider` in
/// app_router.dart) — true for every brand-new account whether they
/// signed up with Google or email/password. An existing account with a
/// name already set never sees this screen; the router redirects past
/// it automatically.
///
/// Mirrors apps/web's /auth/complete-profile control-for-control: same
/// suggested-name logic (Google's full_name/name claim, else a
/// title-cased guess from the email's local part), same one field, same
/// "Continue" action.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _nameController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _suggestedName());
  }

  String _suggestedName() {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    final metadata = user?.userMetadata;
    final metaName =
        (metadata?['full_name'] as String?) ?? (metadata?['name'] as String?);
    if (metaName != null && metaName.trim().isNotEmpty) return metaName.trim();

    final email = user?.email ?? '';
    final localPart = email.split('@').first;
    if (localPart.isEmpty) return '';
    return localPart
        .split(RegExp(r'[._-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await ref.read(profileRepositoryProvider).updateDisplayName(userId, name);
      ref.invalidate(currentProfileProvider);
      // needsOnboardingProvider flips false once currentProfileProvider
      // resolves with the new name, and the router redirects away on
      // its own — no manual navigation needed here.
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Welcome to LOOP',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'What should we call you?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'NAME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textStructural,
                      letterSpacing: 1.5,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitting ? null : _submit(),
                    decoration: const InputDecoration(),
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
                        onPressed: _submitting ? null : _submit,
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
                            : const Text('Continue'),
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
}
