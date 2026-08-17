import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/root_shell.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/business/business_screen.dart';
import '../../features/business/contacts/contacts_screen.dart';
import '../../features/business/leads/leads_screen.dart';
import '../../features/business/opportunities/opportunities_screen.dart';
import '../../features/business/quotes/quotes_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/money/purchases/purchases_screen.dart';
import '../../features/sell/sell_screen.dart';
import '../../features/today/today_screen.dart';

/// Route paths for the top-level tabs. Kept centralized so navigation
/// destinations (e.g. deep links from a notification) can reference a
/// single source of truth.
///
/// Sub-screens (purchases, contacts, leads, opportunities, quotes) are
/// pushed routes nested under their tab's branch — see
/// docs/DECISIONS.md "Where MAKE/PROTECT/RECOVER UI lives in the 5-tab
/// nav" — not new bottom-nav destinations, so they're reached via
/// `context.push()` rather than listed here.
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
                routes: [
                  GoRoute(
                    path: 'purchases',
                    builder: (context, state) => const PurchasesScreen(),
                  ),
                ],
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
                routes: [
                  GoRoute(
                    path: 'contacts',
                    builder: (context, state) => const ContactsScreen(),
                  ),
                  GoRoute(
                    path: 'leads',
                    builder: (context, state) => const LeadsScreen(),
                  ),
                  GoRoute(
                    path: 'opportunities',
                    builder: (context, state) => const OpportunitiesScreen(),
                  ),
                  GoRoute(
                    path: 'quotes',
                    builder: (context, state) => const QuotesScreen(),
                  ),
                ],
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
