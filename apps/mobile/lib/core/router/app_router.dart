import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/root_shell.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/business/business_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/sell/sell_screen.dart';
import '../../features/today/today_screen.dart';

/// Route paths for the top-level tabs. Kept centralized so navigation
/// destinations (e.g. deep links from a notification) can reference a
/// single source of truth.
class AppRoutes {
  const AppRoutes._();

  static const today = '/today';
  static const money = '/money';
  static const sell = '/sell';
  static const business = '/business';
  static const ai = '/ai';
}

/// The app's single GoRouter instance, exposed as a Riverpod provider so
/// it can later depend on auth state (e.g. redirecting to a sign-in flow).
///
/// Uses a StatefulShellRoute so the bottom navigation bar (built in
/// [RootShell]) persists across tab switches while each tab keeps its own
/// navigation stack.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.today,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return RootShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.money,
                builder: (context, state) => const MoneyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sell,
                builder: (context, state) => const SellScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.business,
                builder: (context, state) => const BusinessScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ai,
                builder: (context, state) => const AiScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
