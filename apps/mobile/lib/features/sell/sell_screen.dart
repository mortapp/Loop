import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/placeholder_screen.dart';

/// The Sell tab: the RECOVER-facing surface (ResellLens) — valuing items
/// you own, listing them, and tracking resale through to a completed sale,
/// closing the OWN -> RESELL -> EARN AGAIN loop.
class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Sell',
      icon: Icons.sell_outlined,
      description:
          'Value what you own, list it, and track the sale — turning '
          'items you no longer need back into cash.',
      accentColor: AppColors.recoverAccent,
    );
  }
}
