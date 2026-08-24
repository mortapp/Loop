// Basic smoke tests for the LOOP mobile app shell and the Today screen.
//
// `StatefulShellRoute.indexedStack` branches default to `preload: false`
// (see go_router's `StatefulShellBranch.preload` docs), so only the
// initial branch (Today) is actually built when the app first pumps —
// Money/Sell/Business/AI stay unbuilt until navigated to. That means only
// Today's Supabase-backed provider needs overriding here to keep this
// test hermetic; the other tabs never touch the network in this test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop_mobile/core/auth/google_oauth_controller.dart';
import 'package:loop_mobile/core/router/app_router.dart';
import 'package:loop_mobile/core/utils/money.dart';
import 'package:loop_mobile/features/today/today_providers.dart';
import 'package:loop_mobile/features/onboarding/onboarding_screen.dart';
import 'package:loop_mobile/main.dart';

void main() {
  testWidgets('App boots on Today tab with all navigation destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => true),
          profileGateProvider.overrideWith((ref) => ProfileGateState.complete),
          todayActionsProvider.overrideWith((ref) async => []),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Today is the initial route; its screen and nav label should be
    // visible (possibly more than once, since the tab shows both).
    expect(find.text('Today'), findsWidgets);

    // All five bottom navigation destinations should be present.
    expect(find.text('Money'), findsOneWidget);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
  });

  testWidgets('Today tab shows the empty state when there are no actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => true),
          profileGateProvider.overrideWith((ref) => ProfileGateState.complete),
          todayActionsProvider.overrideWith((ref) async => []),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing open. Add something above.'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('Unauthenticated users are redirected to sign-in, not Today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => false),
          profileGateProvider.overrideWith(
            (ref) => ProfileGateState.notAuthenticated,
          ),
          googleOAuthGatewayProvider.overrideWithValue(
            const _UnavailableOAuthGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Nothing open. Add something above.'), findsNothing);
  });

  testWidgets('Signed-in users cannot reach Today while profile is loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => true),
          profileGateProvider.overrideWith((ref) => ProfileGateState.loading),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Nothing open. Add something above.'), findsNothing);
  });

  testWidgets('Signed-in incomplete profiles reach canonical onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => true),
          profileGateProvider.overrideWith(
            (ref) => ProfileGateState.requiresOnboarding,
          ),
          onboardingIdentityProvider.overrideWithValue(
            const OnboardingIdentityState(
              userId: 'new-user',
              email: 'new.user@example.com',
              suggestedName: 'New User',
              suggestedUsername: 'newuser',
              credentialsRequired: false,
            ),
          ),
          onboardingUsernameAvailabilityProvider.overrideWithValue(
            (_) async => true,
          ),
          onboardingSubmitterProvider.overrideWithValue((_) async {}),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Welcome to LOOP'), findsOneWidget);
    expect(find.text('Nothing open. Add something above.'), findsNothing);
  });

  group('MoneyUtils', () {
    test('dollarsStringToCents parses dollar strings to integer cents', () {
      expect(MoneyUtils.dollarsStringToCents('12.34'), 1234);
      expect(MoneyUtils.dollarsStringToCents('0.01'), 1);
      expect(MoneyUtils.dollarsStringToCents('0'), 0);
      expect(MoneyUtils.dollarsStringToCents('1000000000.00'), 100000000000);
      expect(MoneyUtils.dollarsStringToCents(''), isNull);
      expect(MoneyUtils.dollarsStringToCents('not a number'), isNull);
      expect(MoneyUtils.dollarsStringToCents('1.005'), isNull);
      expect(MoneyUtils.dollarsStringToCents('1e3'), isNull);
      expect(MoneyUtils.dollarsStringToCents('-1'), isNull);
      expect(MoneyUtils.dollarsStringToCents('1000000000.01'), isNull);
    });

    test('formatCents renders grouped, signed dollar strings', () {
      expect(MoneyUtils.formatCents(123456), r'$1,234.56');
      expect(MoneyUtils.formatCents(-500), r'-$5.00');
      expect(MoneyUtils.formatCents(null), '—');
    });
  });
}

class _UnavailableOAuthGateway implements GoogleOAuthGateway {
  const _UnavailableOAuthGateway();

  @override
  Stream<MobileAuthSignal> get authSignals => const Stream.empty();

  @override
  String? get currentSessionUserId => null;

  @override
  String? get currentUserId => null;

  @override
  Future<bool> launchGoogle() async => false;
}
