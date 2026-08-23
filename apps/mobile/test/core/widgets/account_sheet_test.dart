import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/profile_providers.dart';
import 'package:loop_mobile/core/widgets/account_sheet.dart';

void main() {
  testWidgets('account avatar exposes an accessible control name', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentProfileProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(home: Scaffold(body: AccountAvatarButton())),
      ),
    );

    expect(find.byTooltip('Account menu'), findsOneWidget);
  });
}
