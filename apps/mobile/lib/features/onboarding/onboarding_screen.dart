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

enum _UsernameStatus { idle, invalid, checking, available, taken, unavailable }

@immutable
class OnboardingIdentityState {
  const OnboardingIdentityState({
    required this.userId,
    required this.email,
    required this.suggestedName,
    required this.suggestedUsername,
    required this.credentialsRequired,
  });

  factory OnboardingIdentityState.fromUser(User? user) {
    final email = user?.email ?? '';
    final localPart = email.split('@').first;
    final metadata = user?.userMetadata;
    final fullName = metadata?['full_name'];
    final name = metadata?['name'];
    final metadataName = fullName is String
        ? fullName
        : name is String
        ? name
        : null;
    final suggestedName = metadataName?.trim().isNotEmpty ?? false
        ? metadataName!.trim()
        : _titleCase(localPart);

    final cleanedUsername = localPart.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '',
    );
    final suggestedUsername = cleanedUsername.length > 20
        ? cleanedUsername.substring(0, 20)
        : cleanedUsername;

    final providers = <String>{};
    for (final identity in user?.identities ?? const <UserIdentity>[]) {
      providers.add(identity.provider.toLowerCase());
    }
    final metadataProviders = user?.appMetadata['providers'];
    if (metadataProviders is Iterable) {
      providers.addAll(
        metadataProviders.whereType<String>().map(
          (value) => value.toLowerCase(),
        ),
      );
    }
    final primaryProvider = user?.appMetadata['provider'];
    if (primaryProvider is String) {
      providers.add(primaryProvider.toLowerCase());
    }

    return OnboardingIdentityState(
      userId: user?.id ?? '',
      email: email,
      suggestedName: suggestedName,
      suggestedUsername: suggestedUsername.length >= 3 ? suggestedUsername : '',
      credentialsRequired: user != null && !providers.contains('email'),
    );
  }

  final String userId;
  final String email;
  final String suggestedName;
  final String suggestedUsername;
  final bool credentialsRequired;

  static String _titleCase(String localPart) {
    if (localPart.isEmpty) return '';
    return localPart
        .split(RegExp(r'[._-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

@immutable
class OnboardingSubmission {
  const OnboardingSubmission({
    required this.userId,
    required this.displayName,
    required this.username,
    this.password,
  });

  final String userId;
  final String displayName;
  final String username;
  final String? password;
}

typedef UsernameAvailabilityChecker = Future<bool> Function(String username);
typedef OnboardingSubmitter =
    Future<void> Function(OnboardingSubmission submission);

/// The current signed-in identity as needed by the onboarding presentation.
/// Production reads the real Supabase session; focused tests override it.
final onboardingIdentityProvider = Provider<OnboardingIdentityState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return OnboardingIdentityState.fromUser(client.auth.currentUser);
});

final onboardingUsernameAvailabilityProvider =
    Provider<UsernameAvailabilityChecker>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return (username) async {
        final result = await client.rpc(
          'is_username_available',
          params: {'candidate': username},
        );
        return result == true;
      };
    });

final onboardingSubmitterProvider = Provider<OnboardingSubmitter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);

  return (submission) async {
    if (client.auth.currentUser?.id != submission.userId) {
      throw const _OnboardingSessionUnavailable();
    }

    if (submission.password != null) {
      await client.auth.updateUser(
        UserAttributes(password: submission.password),
      );
    }

    await profileRepository.completeProfile(
      userId: submission.userId,
      displayName: submission.displayName,
      username: submission.username,
    );
  };
});

class _OnboardingSessionUnavailable implements Exception {
  const _OnboardingSessionUnavailable();
}

/// The single canonical native account-completion screen.
///
/// Google-created accounts without email credentials must create and confirm
/// a password. Existing email/password users retain the profile-only flow.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final OnboardingIdentityState _identity;
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _debounce;
  int _usernameRequestGeneration = 0;
  bool _submitting = false;
  bool _submissionFailed = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _identity = ref.read(onboardingIdentityProvider);
    _nameController = TextEditingController(text: _identity.suggestedName);
    _usernameController = TextEditingController(
      text: _identity.suggestedUsername,
    )..addListener(_onUsernameChanged);
    _onUsernameChanged();
  }

  void _onUsernameChanged() {
    _scheduleUsernameCheck();
    _clearSubmissionFeedback();
  }

  void _scheduleUsernameCheck({bool immediate = false}) {
    _debounce?.cancel();
    final generation = ++_usernameRequestGeneration;
    final candidate = _usernameController.text.trim().toLowerCase();

    if (candidate.isEmpty) {
      _setUsernameStatus(_UsernameStatus.idle);
      return;
    }
    if (!_usernamePattern.hasMatch(candidate)) {
      _setUsernameStatus(_UsernameStatus.invalid);
      return;
    }

    _setUsernameStatus(_UsernameStatus.checking);
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 400),
      () async {
        final checker = ref.read(onboardingUsernameAvailabilityProvider);
        try {
          final available = await checker(candidate);
          if (!mounted || generation != _usernameRequestGeneration) return;
          if (_usernameController.text.trim().toLowerCase() != candidate) {
            return;
          }
          setState(
            () => _usernameStatus = available
                ? _UsernameStatus.available
                : _UsernameStatus.taken,
          );
        } catch (_) {
          if (!mounted || generation != _usernameRequestGeneration) return;
          setState(() => _usernameStatus = _UsernameStatus.unavailable);
        }
      },
    );
  }

  void _setUsernameStatus(_UsernameStatus status) {
    if (_usernameStatus == status) return;
    setState(() => _usernameStatus = status);
  }

  void _clearSubmissionFeedback() {
    if (_error == null && !_submissionFailed) return;
    setState(() {
      _error = null;
      _submissionFailed = false;
    });
  }

  void _handleFieldChanged(String _) => _clearSubmissionFeedback();

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameRequestGeneration++;
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String? _validationMessage() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (name.isEmpty) return 'Enter your name.';
    if (username.isEmpty) return 'Choose a username.';
    if (!_usernamePattern.hasMatch(username)) {
      return 'Use 3-20 lowercase letters, numbers, or underscores.';
    }
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return 'Wait for the username check to finish.';
      case _UsernameStatus.taken:
        return 'That username is already taken.';
      case _UsernameStatus.unavailable:
        return 'Check username availability before continuing.';
      case _UsernameStatus.idle:
      case _UsernameStatus.invalid:
        return 'Choose a valid username.';
      case _UsernameStatus.available:
        break;
    }

    if (_identity.credentialsRequired) {
      final password = _passwordController.text;
      final confirmation = _confirmPasswordController.text;
      if (password.isEmpty) return 'Create a password to continue.';
      if (password.length < 8) {
        return 'Password must be at least 8 characters.';
      }
      if (confirmation.isEmpty) return 'Confirm your password.';
      if (password != confirmation) return "Passwords don't match.";
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final validationMessage = _validationMessage();
    if (validationMessage != null) {
      setState(() {
        _error = validationMessage;
        _submissionFailed = false;
      });
      return;
    }
    if (_identity.userId.isEmpty) {
      setState(() {
        _error = 'Your session expired. Sign in again and retry setup.';
        _submissionFailed = true;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final submitter = ref.read(onboardingSubmitterProvider);
    final submission = OnboardingSubmission(
      userId: _identity.userId,
      displayName: _nameController.text.trim(),
      username: _usernameController.text.trim().toLowerCase(),
      password: _identity.credentialsRequired ? _passwordController.text : null,
    );

    setState(() {
      _submitting = true;
      _submissionFailed = false;
      _error = null;
    });

    try {
      await submitter(submission);
      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _safeSubmissionMessage(error);
        _submissionFailed = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _safeSubmissionMessage(Object error) {
    if (error is _OnboardingSessionUnavailable) {
      return 'Your session expired. Sign in again and retry setup.';
    }
    if (error is PostgrestException) {
      if (error.code == '23505') return 'That username is already taken.';
      if (error.code == '23514') {
        return 'That username is not allowed. Try a different one.';
      }
      return 'We could not save your profile. '
          'Check your connection and try again.';
    }
    if (error is AuthException) {
      return 'We could not secure your account. '
          'Check the password and try again.';
    }
    if (error is TimeoutException) {
      return 'The request timed out. Check your connection and try again.';
    }
    return 'We could not finish setup. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 380 ? 20.0 : AppSpacing.lg;

    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: SingleChildScrollView(
            key: const Key('onboarding-scroll-view'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LoopSeal(size: 32)),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        'ACCOUNT SETUP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.tyrianText,
                          letterSpacing: 1.2,
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
                    const _FieldLabel('EMAIL'),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      label: 'Account email',
                      readOnly: true,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          border: Border.all(
                            color: AppColors.platinum.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _identity.email,
                          softWrap: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _FieldLabel('NAME'),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      label: 'Name',
                      textField: true,
                      child: TextField(
                        key: const Key('onboarding-name-field'),
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        enabled: !_submitting,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        onChanged: _handleFieldChanged,
                        onSubmitted: (_) => _usernameFocusNode.requestFocus(),
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _FieldLabel('USERNAME'),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      label: 'Username',
                      textField: true,
                      child: TextField(
                        key: const Key('onboarding-username-field'),
                        controller: _usernameController,
                        focusNode: _usernameFocusNode,
                        enabled: !_submitting,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: _identity.credentialsRequired
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) {
                          if (_identity.credentialsRequired) {
                            _passwordFocusNode.requestFocus();
                          } else {
                            _submit();
                          }
                        },
                        decoration: const InputDecoration(
                          prefixText: '@',
                          hintText: 'your_username',
                        ),
                      ),
                    ),
                    if (_usernameHint() != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (_usernameStatus ==
                                _UsernameStatus.checking) ...[
                              const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                _usernameHint()!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _usernameHintColor(),
                                ),
                              ),
                            ),
                            if (_usernameStatus == _UsernameStatus.unavailable)
                              TextButton(
                                key: const Key('onboarding-username-retry'),
                                onPressed: _submitting
                                    ? null
                                    : () => _scheduleUsernameCheck(
                                        immediate: true,
                                      ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_identity.credentialsRequired) ...[
                      const SizedBox(height: AppSpacing.md),
                      const _FieldLabel('PASSWORD', required: true),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        label: 'Password, required',
                        textField: true,
                        child: TextField(
                          key: const Key('onboarding-password-field'),
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          enabled: !_submitting,
                          obscureText: !_passwordVisible,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: _handleFieldChanged,
                          onSubmitted: (_) =>
                              _confirmPasswordFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            hintText: 'At least 8 characters',
                            suffixIcon: IconButton(
                              key: const Key('onboarding-password-visibility'),
                              tooltip: _passwordVisible
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () =>
                                          _passwordVisible = !_passwordVisible,
                                    ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Required to finish setting up this Google account.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _FieldLabel('CONFIRM PASSWORD', required: true),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        label: 'Confirm password, required',
                        textField: true,
                        child: TextField(
                          key: const Key('onboarding-confirm-password-field'),
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          enabled: !_submitting,
                          obscureText: !_confirmPasswordVisible,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: _handleFieldChanged,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Enter the same password again',
                            suffixIcon: IconButton(
                              key: const Key(
                                'onboarding-confirm-password-visibility',
                              ),
                              tooltip: _confirmPasswordVisible
                                  ? 'Hide confirmation password'
                                  : 'Show confirmation password',
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () => _confirmPasswordVisible =
                                          !_confirmPasswordVisible,
                                    ),
                              icon: Icon(
                                _confirmPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        liveRegion: true,
                        container: true,
                        label: 'Setup error: $_error',
                        child: Container(
                          key: const Key('onboarding-error'),
                          padding: const EdgeInsets.all(AppSpacing.sm + 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.dangerText,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.dangerText,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                          key: const Key('onboarding-submit'),
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onAccentFill,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Flexible(child: Text('Finishing setup...')),
                                  ],
                                )
                              : Text(
                                  _submissionFailed
                                      ? 'Try setup again'
                                      : 'Finish setup',
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
        return 'Checking availability';
      case _UsernameStatus.available:
        return 'Username available';
      case _UsernameStatus.taken:
        return 'Username already taken';
      case _UsernameStatus.unavailable:
        return 'Could not check availability.';
    }
  }

  Color _usernameHintColor() {
    switch (_usernameStatus) {
      case _UsernameStatus.available:
        return AppColors.tyrianText;
      case _UsernameStatus.invalid:
      case _UsernameStatus.taken:
      case _UsernameStatus.unavailable:
        return AppColors.dangerText;
      case _UsernameStatus.idle:
      case _UsernameStatus.checking:
        return AppColors.textMuted;
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.textStructural,
      letterSpacing: 1.3,
      fontSize: 11,
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: style),
        if (required)
          Text(
            'REQUIRED',
            style: style?.copyWith(
              color: AppColors.tyrianText,
              letterSpacing: 0.8,
            ),
          ),
      ],
    );
  }
}
