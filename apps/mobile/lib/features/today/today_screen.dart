import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// The Today tab: a unified action feed spanning every engine — quotes to
/// close (MAKE), returns/warranties needing attention (PROTECT), and
/// resell opportunities (RECOVER) — surfaced as one prioritized list.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Today',
      icon: Icons.today_outlined,
      description:
          'Your unified action feed. Quotes to close, returns to handle, '
          'and resell opportunities — all in one prioritized list, across '
          'every business you work with.',
    );
  }
}
