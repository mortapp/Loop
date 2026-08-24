import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/profile_providers.dart';
import 'package:loop_mobile/core/theme/app_theme.dart';
import 'package:loop_mobile/features/sell/sell_providers.dart';
import 'package:loop_mobile/features/sell/sell_screen.dart';

void main() {
  testWidgets('empty Sell ledger opens one focused Add item sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => null),
          sellPageProvider.overrideWith(
            (ref) async => const SellPageData(
              items: [],
              latestValuationByItem: {},
              listingsByItem: {},
              signedUrlByPath: {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const SellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.byKey(const Key('sell-add-item-action')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('sell-add-item-action')));
    await tester.pumpAndSettle();

    expect(find.text('Item name'), findsOneWidget);
    expect(find.text('Category (optional)'), findsOneWidget);
    expect(find.text('Condition (optional)'), findsOneWidget);
    expect(find.text(r'Paid ($, optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
