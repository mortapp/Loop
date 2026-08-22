// Basic smoke tests for the LOOP mobile app shell and the Today screen.
//
// `StatefulShellRoute.indexedStack` branches default to `preload: false`
// (see go_router's `StatefulShellBranch.preload` docs), so only the
// initial branch (Today) is actually built when the app first pumps —
// Money/Sell/Business/AI stay unbuilt until navigated to. That means only
// Today's Supabase-backed provider needs overriding here to keep this
// test hermetic; the other tabs never touch the network in this test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop_mobile/core/router/app_router.dart';
import 'package:loop_mobile/core/utils/money.dart';
import 'package:loop_mobile/features/today/today_providers.dart';
import 'package:loop_mobile/main.dart';

void main() {
  testWidgets('App boots on Today tab with all navigation destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => true),
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
        overrides: [isAuthenticatedProvider.overrideWith((ref) => false)],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Nothing open. Add something above.'), findsNothing);
  });

  group('MoneyUtils', () {
    test('dollarsStringToCents parses dollar strings to integer cents', () {
      expect(MoneyUtils.dollarsStringToCents('12.34'), 1234);
      expect(MoneyUtils.dollarsStringToCents('0.01'), 1);
      expect(MoneyUtils.dollarsStringToCents(''), isNull);
      expect(MoneyUtils.dollarsStringToCents('not a number'), isNull);
    });

    test('formatCents renders grouped, signed dollar strings', () {
      expect(MoneyUtils.formatCents(123456), r'$1,234.56');
      expect(MoneyUtils.formatCents(-500), r'-$5.00');
      expect(MoneyUtils.formatCents(null), '—');
    });
  });
}
