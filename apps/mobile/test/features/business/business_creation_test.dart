import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/account_context.dart';
import 'package:loop_mobile/core/account/account_providers.dart';
import 'package:loop_mobile/features/business/business_repository.dart';
import 'package:loop_mobile/features/business/business_screen.dart';
import 'package:loop_mobile/features/business/contacts/contacts_providers.dart';
import 'package:loop_mobile/features/business/opportunities/opportunities_providers.dart';
import 'package:loop_mobile/features/business/quotes/quotes_providers.dart';

const _personal = AccountSummary(
  id: 'personal',
  kind: AccountKind.personal,
  displayName: 'Personal',
);
const _business = AccountSummary(
  id: 'business',
  kind: AccountKind.business,
  displayName: 'North Star Studio',
  role: 'owner',
);

void main() {
  test('business names produce safe non-empty slug bases', () {
    expect(slugifyBusinessName(' North Star Studio! '), 'north-star-studio');
    expect(slugifyBusinessName('東京'), 'business');
  });

  testWidgets('Create business action submits and selects the new account', (
    tester,
  ) async {
    String? submittedName;
    final container = ProviderContainer(
      overrides: [
        activeAccountProvider.overrideWith(
          () => _TestActiveAccountNotifier(_personal),
        ),
        availableAccountsProvider.overrideWith(
          (ref) async => const [_personal, _business],
        ),
        businessCreatorProvider.overrideWithValue((name) async {
          submittedName = name;
          return _business.id;
        }),
        contactsProvider.overrideWith((ref) async => const []),
        opportunitiesProvider.overrideWith((ref) async => const []),
        quotesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BusinessScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-business-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('business-name-field')),
      '  North Star Studio  ',
    );
    await tester.tap(find.byKey(const Key('create-business-submit')));
    await tester.pumpAndSettle();

    expect(submittedName, 'North Star Studio');
    expect(container.read(activeAccountProvider).id, _business.id);
    expect(find.text('North Star Studio is ready.'), findsOneWidget);
  });

  for (final textScale in [1.0, 1.5]) {
    testWidgets('Ledger 2.0 fits Galaxy A14 portrait at ${textScale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 2.8125;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWith(
            () => _TestActiveAccountNotifier(_personal),
          ),
          availableAccountsProvider.overrideWith(
            (ref) async => const [_personal],
          ),
          contactsProvider.overrideWith((ref) async => const []),
          opportunitiesProvider.overrideWith((ref) async => const []),
          quotesProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: const BusinessScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('business-create-quote-action')),
        findsOneWidget,
      );
      for (final title in ['PEOPLE', 'WORK', 'QUOTES']) {
        await tester.scrollUntilVisible(
          find.text(title),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

class _TestActiveAccountNotifier extends ActiveAccountNotifier {
  _TestActiveAccountNotifier(this.initial);

  final AccountSummary initial;

  @override
  AccountSummary build() => initial;

  @override
  void select(AccountSummary account) => state = account;
}
