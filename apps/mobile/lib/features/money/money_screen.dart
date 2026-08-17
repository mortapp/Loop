import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// The Money tab: a unified view of value moving through LOOP — money
/// earned via MAKE, money protected/recovered via PROTECT, and money
/// recovered via RECOVER resales, all expressed through shared value
/// primitives.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Money',
      icon: Icons.account_balance_wallet_outlined,
      description:
          'Every dollar earned, protected, and recovered — quote revenue, '
          'return/warranty value, and resale proceeds — in one shared '
          'ledger view.',
    );
  }
}
