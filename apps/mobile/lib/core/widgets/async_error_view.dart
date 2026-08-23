import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
export '../utils/user_safe_error.dart';

/// Shared "something went wrong" body used by every feature screen's
/// [AsyncValue.when] error branch, with a retry action. The underlying error
/// is intentionally never rendered: PostgREST errors can contain table,
/// policy, constraint, and internal identifier details.
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Something went wrong. Check your connection and try again.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a snackbar for a user-facing error message. Centralized so every
/// feature screen surfaces failures the same way.
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
