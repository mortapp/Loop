import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'loop_seal.dart';

/// The persistent bottom-navigation shell wrapping every top-level tab:
/// Today, Money, Sell, Business, AI.
///
/// This is shared chrome — the same shell hosts screens backed by any of
/// the three engines (MAKE, PROTECT, RECOVER), which is what keeps LOOP
/// feeling like one app instead of three bolted-together ones.
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Money',
    ),
    NavigationDestination(
      icon: Icon(Icons.sell_outlined),
      selectedIcon: Icon(Icons.sell),
      label: 'Sell',
    ),
    NavigationDestination(
      icon: Icon(Icons.business_outlined),
      selectedIcon: Icon(Icons.business),
      label: 'Business',
    ),
    // No robot/sparkle glyph — the Double Loop Seal identifies AI the
    // same way it identifies generated content elsewhere in the app.
    NavigationDestination(
      icon: LoopSeal(size: 22, keyPoint: false, opacity: 0.7),
      selectedIcon: LoopSeal(size: 22, keyPoint: false),
      label: 'AI',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: _destinations,
      ),
    );
  }
}
