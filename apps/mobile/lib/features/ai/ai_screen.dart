import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/account_sheet.dart';
import '../../core/widgets/loop_seal.dart';

/// "Ask LOOP" — mirrors apps/web/src/app/(app)/ai exactly: a Fraunces
/// heading, the Loop Seal (never a robot/sparkle icon), and an honest
/// state instead of a generic "coming soon" placeholder. There is no
/// mobile AI backend yet (web's /api/ai/chat + /api/ai/confirm tool
/// registry has no Flutter-side client) — say that plainly rather than
/// implying a working chat that doesn't exist.
class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI'),
        actions: const [AccountAvatarButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Ask LOOP',
              style: GoogleFonts.fraunces(
                textStyle: theme.textTheme.headlineMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'What should we work through? Nothing here executes '
              'without you approving it first.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LoopSeal(size: 32, keyPoint: false, opacity: 0.6),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "Ask LOOP isn't available on mobile yet.",
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Use LOOP on the web to draft follow-ups, review a '
                      'return, or summarize your priorities. The '
                      'confirm-before-it-runs tool registry lives there '
                      'today — a mobile client is real, scoped follow-up '
                      'work.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
