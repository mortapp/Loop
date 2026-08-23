import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../account/profile_providers.dart';
import '../auth/mobile_auth_contract.dart';
import '../supabase/supabase_providers.dart';
import '../widgets/root_shell.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/business/business_screen.dart';
import '../../features/business/contacts/contacts_screen.dart';
import '../../features/business/leads/leads_screen.dart';
import '../../features/business/opportunities/opportunities_screen.dart';
import '../../features/business/quotes/quotes_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/money/purchases/purchases_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/sell/sell_screen.dart';
import '../../features/settings/personalization_screen.dart';
import '../../features/settings/settings_screen.dart';
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
  static const accountGate = '/account-gate';
  static const signIn = '/sign-in';
  static const onboarding = '/onboarding';
  static const profile = '/profile';
  static const settings = '/settings';
  static const personalization = '/settings/personalization';
  static const help = '/help';
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
  final auth = Supabase.instance.client.auth;
  return MobileAuthContract.hasConsistentSession(
    sessionUserId: auth.currentSession?.user.id,
    currentUserId: auth.currentUser?.id,
  );
});

enum ProfileGateState {
  notAuthenticated,
  loading,
  requiresOnboarding,
  complete,
  error,
}

/// Server-authoritative profile gate. Loading and errors are explicit states,
/// so a signed-in account can never briefly reach Today while its profile is
/// unresolved. Both display name and username are required for completion.
final profileGateProvider = Provider<ProfileGateState>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) {
    return ProfileGateState.notAuthenticated;
  }

  return ref
      .watch(currentProfileProvider)
      .when(
        data: (profile) {
          if (profile == null) return ProfileGateState.error;
          return profile.hasCompletedOnboarding
              ? ProfileGateState.complete
              : ProfileGateState.requiresOnboarding;
        },
        error: (_, _) => ProfileGateState.error,
        loading: () => ProfileGateState.loading,
      );
});

/// Compatibility wrapper retained for focused widget overrides and consumers
/// that only need the yes/no answer.
final needsOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(profileGateProvider) == ProfileGateState.requiresOnboarding;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// The app's single GoRouter instance, exposed as a Riverpod provider.
///
/// Uses a StatefulShellRoute so the bottom navigation bar (built in
/// [RootShell]) persists across tab switches while each tab keeps its own
/// navigation stack.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<bool>(
    isAuthenticatedProvider,
    (_, _) => refreshNotifier.refresh(),
  );
  ref.listen<ProfileGateState>(
    profileGateProvider,
    (_, _) => refreshNotifier.refresh(),
  );
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.accountGate,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final profileGate = ref.read(profileGateProvider);
      final goingToAccountGate = state.matchedLocation == AppRoutes.accountGate;
      final goingToSignIn = state.matchedLocation == AppRoutes.signIn;
      final goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (!isAuthenticated) {
        return goingToSignIn ? null : AppRoutes.signIn;
      }

      switch (profileGate) {
        case ProfileGateState.loading:
        case ProfileGateState.error:
        case ProfileGateState.notAuthenticated:
          return goingToAccountGate ? null : AppRoutes.accountGate;
        case ProfileGateState.requiresOnboarding:
          return goingToOnboarding ? null : AppRoutes.onboarding;
        case ProfileGateState.complete:
          if (goingToAccountGate || goingToSignIn || goingToOnboarding) {
            return AppRoutes.today;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.accountGate,
        builder: (context, state) => const _AccountGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Account identity — full-screen pushes (with a back button) reached
      // from the account sheet, not new bottom-nav destinations.
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'personalization',
            builder: (context, state) => const PersonalizationScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (context, state) => const HelpScreen(),
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

class _AccountGateScreen extends ConsumerWidget {
  const _AccountGateScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(profileGateProvider);
    final hasError = gate == ProfileGateState.error;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasError)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    'LOOP could not verify your account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check your connection, then try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => ref.invalidate(currentProfileProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
