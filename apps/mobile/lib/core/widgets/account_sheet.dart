import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/account_providers.dart';
import '../account/profile_providers.dart';
import '../supabase/supabase_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The account identity control — avatar + name opens this bottom sheet:
/// Account / Profile / Appearance / Help / Sign out. No
/// billing/plan/upgrade rows: LOOP has no subscription tiers, so those
/// would be copied UI, not an earned feature.
class AccountAvatarButton extends ConsumerWidget {
  const AccountAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final email = profileAsync.asData?.value?.email ?? '';
    final displayName = profileAsync.asData?.value?.displayName;
    final initials = email.isEmpty ? '?' : initialsFor(displayName, email);

    return IconButton(
      tooltip: 'Account menu',
      onPressed: () => showAccountSheet(context),
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.tyrianRoyal,
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.onAccentFill,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

void showAccountSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.asData?.value;
    final activeAccount = ref.watch(activeAccountProvider);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.murexInk,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(18),
            bottom: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.platinum.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.smokedPlatinum.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName?.trim().isNotEmpty == true
                              ? profile!.displayName!
                              : (profile?.email ?? 'Your account'),
                          style: theme.textTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile?.email ?? '',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activeAccount.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.tyrianText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const _SheetDivider(),
            _SheetItem(
              label: 'Account',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
            _SheetItem(
              label: 'Profile',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
            ),
            _SheetItem(
              label: 'Appearance',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings/personalization');
              },
            ),
            _SheetItem(
              label: 'Help',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/help');
              },
            ),
            const _SheetDivider(),
            _SheetItem(
              label: 'Sign out',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(supabaseClientProvider).auth.signOut();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppColors.platinum.withValues(alpha: 0.12),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
