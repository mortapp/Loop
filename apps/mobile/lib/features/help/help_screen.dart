import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

const _topics = <(String, String)>[
  (
    'Getting started',
    'LOOP tracks one loop: Earn → Buy → Own → Return or resell → Earn '
        'again. Today is your queue of what needs attention right now; '
        'Money is the ledger everything else writes to.',
  ),
  (
    'Today',
    "Add anything you need to do. Quote follow-ups, return deadlines, "
        "and resale opportunities will start appearing here on their own "
        "as those features mature — for now, add items manually.",
  ),
  (
    'MAKE — Business',
    'Contacts → Leads → Opportunities → Quotes. A lead is interest that '
        "isn't qualified yet; an opportunity is worth writing a quote "
        'for. Quote totals are calculated from real line items, not '
        'typed in by hand.',
  ),
  (
    'PROTECT — Money → Purchases',
    'Record what you buy to track return windows and warranties before '
        'they expire. Return status moves through initiated → shipped → '
        'received → refunded (or denied). A refund posts straight to '
        'your Money ledger.',
  ),
  (
    'RECOVER — Sell',
    'Add an item, value it, list it, then record the sale. A completed '
        'sale posts to Money as recovered value automatically — you '
        'never enter it twice.',
  ),
  (
    'Account & accounts',
    '"Account" in LOOP means whichever business or personal ledger is '
        'currently active — switch it from the account menu or '
        'Business. Your profile (name, email) is separate from which '
        'account is active.',
  ),
  (
    'Troubleshooting',
    "If a page looks stuck after an action, pull to refresh — most "
        "actions update automatically, but a slow network can leave a "
        "stale view. If something looks wrong with your data "
        "specifically, it's real data, not a display bug — check the "
        "underlying record before assuming LOOP miscalculated.",
  ),
];

/// Real, honest in-app help — mirrors apps/web/src/app/(app)/help.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              "LOOP doesn't have a published Privacy Policy or Terms of "
              "Service yet, and there's no support inbox monitored "
              "outside this app — this page is what exists today.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final (title, body) in _topics)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
