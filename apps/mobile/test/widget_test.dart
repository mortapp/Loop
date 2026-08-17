// Basic smoke test for the LOOP mobile app shell: verifies the app boots
// under a ProviderScope and lands on the Today tab with all five bottom
// navigation destinations present.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop_mobile/main.dart';

void main() {
  testWidgets('App boots on Today tab with all navigation destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LoopApp()));
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
}
