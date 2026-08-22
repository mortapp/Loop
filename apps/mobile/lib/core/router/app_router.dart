import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import '../widgets/root_shell.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/auth/auth_screen.dart';
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
  static const signIn = '/sign-in';
}

/// Whether a Supabase session currently exists — a thin, overridable
/// wrapper around `client.auth.currentSession` rather than the router
/// reading it directly, so widget tests can simulate a signed-in state
/// with `isAuthenticatedProvider.overrideWith((ref) => true)` instead of
/// needing a real Supabase backend.
///
/// Watching [authStateChangesProvider] makes this rebuild on every
/// sign-in/sign-out/token-refresh event. Reading `currentSession` directly
/// (rather than the stream's own `AsyncValue`) avoids a loading-state
/// flash-redirect on cold start, since `Supabase.initialize()` has already
/// synchronously restored any persisted session by the time this provider
/// first builds.
final isAuthenticatedProvider = Provider<bool>((ref) {
  ref.watch(authStateChangesProvider);
  return Supabase.instance.client.auth.currentSession != null;
});

/// The app's single GoRouter instance, exposed as a Riverpod provider.
///
/// Uses a StatefulShellRoute so the bottom navigation bar (built in
/// [RootShell]) persists across tab switches while each tab keeps its own
/// navigation stack.
final appRouterProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: AppRoutes.today,
    redirect: (context, state) {
      final goingToSignIn = state.matchedLocation == AppRoutes.signIn;
      if (!isAuthenticated) {
        return goingToSignIn ? null : AppRoutes.signIn;
      }
      if (goingToSignIn) {
        return AppRoutes.today;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const AuthScreen(),
      ),
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
