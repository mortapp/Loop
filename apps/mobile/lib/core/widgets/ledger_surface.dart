import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared presentation primitives for LOOP's private-ledger interface.
///
/// These are deliberately small and data-agnostic. Feature screens keep using
/// their existing providers and repositories while presenting the result with
/// one visual language.
class LedgerPageIntro extends StatelessWidget {
  const LedgerPageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class LedgerSectionLabel extends StatelessWidget {
  const LedgerSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.textStructural,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
    );
    return Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: style)),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 3),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(width: 32, child: Center(child: leading)),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      (emphasized
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.bodyLarge)
                          ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.textTheme.bodyMedium?.color,
            ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.platinum.withValues(alpha: 0.16)),
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: content,
            ),
    );
  }
}

class LedgerEmptyState extends StatelessWidget {
  const LedgerEmptyState({
    super.key,
    required this.title,
    this.detail,
    this.action,
  });

  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detail!, style: theme.textTheme.bodyMedium),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class LedgerHero extends StatelessWidget {
  const LedgerHero({
    super.key,
    required this.eyebrow,
    required this.value,
    this.detail,
    this.action,
  });

  final String eyebrow;
  final Widget value;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.platinum.withValues(alpha: 0.16)),
          bottom: BorderSide(color: AppColors.platinum.withValues(alpha: 0.16)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LedgerSectionLabel(eyebrow),
          const SizedBox(height: AppSpacing.sm),
          value,
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detail!, style: theme.textTheme.bodyMedium),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
