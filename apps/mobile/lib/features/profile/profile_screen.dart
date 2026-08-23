import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/account_providers.dart';
import '../../core/account/profile_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';

/// Real, editable profile — mirrors apps/web/src/app/(app)/profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => profile == null
              ? const Center(child: Text('Not signed in.'))
              : _ProfileBody(profile: profile),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final _nameController = TextEditingController(
    text: widget.profile.displayName ?? '',
  );
  bool _submitting = false;
  String? _error;
  bool _justSaved = false;

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldName = oldWidget.profile.displayName ?? '';
    final newName = widget.profile.displayName ?? '';
    if (!_submitting && _nameController.text == oldName && oldName != newName) {
      _nameController.text = newName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    if (name.length > 100) {
      setState(() => _error = 'Name must be 100 characters or fewer.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _justSaved = false;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateDisplayName(widget.profile.id, name);
      ref.invalidate(currentProfileProvider);
      if (mounted) setState(() => _justSaved = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = userSafeActionError('save your profile'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = initialsFor(
      widget.profile.displayName,
      widget.profile.email,
    );
    final accounts = ref.watch(availableAccountsProvider);
    final active = ref.watch(activeAccountProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.tyrianRoyal,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.onAccentFill,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.displayName?.trim().isNotEmpty == true
                            ? widget.profile.displayName!
                            : widget.profile.email,
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        widget.profile.email,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USERNAME',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textStructural,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '@${widget.profile.username}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Usernames are permanent for now.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISPLAY NAME',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textStructural,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _submitting ? null : _save,
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.dangerText),
                        ),
                      ),
                    ] else if (_justSaved) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text('Saved', style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMAIL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textStructural,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(widget.profile.email, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Changing your sign-in email isn't supported yet.",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNTS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textStructural,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...accounts.maybeWhen(
                  data: (list) => list.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(a.displayName, style: theme.textTheme.bodyLarge),
                          if (a.id == active.id)
                            Text(
                              'Active',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.tyrianText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  orElse: () => const [SizedBox.shrink()],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
