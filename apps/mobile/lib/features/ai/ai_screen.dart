import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

/// The AI tab: a cross-engine assistant that can act on the shared data
/// model — draft a quote, flag a return, price a resale listing — using
/// the same identity, businesses, contacts, items, and documents as the
/// rest of LOOP.
class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'AI',
      icon: Icons.auto_awesome_outlined,
      description:
          'Your assistant across every engine — draft a quote, resolve a '
          'return, or price a resale listing, powered by everything LOOP '
          'already knows about your business.',
    );
  }
}
