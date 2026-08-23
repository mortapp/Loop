import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/account_context.dart';
import 'package:loop_mobile/core/account/account_providers.dart';
import 'package:loop_mobile/core/account/profile_providers.dart';
import 'package:loop_mobile/features/money/models/money_event.dart';
import 'package:loop_mobile/features/money/models/money_totals.dart';
import 'package:loop_mobile/features/money/money_providers.dart';
import 'package:loop_mobile/features/money/money_screen.dart';

const _accountA = AccountSummary(
  id: 'account-a',
  kind: AccountKind.business,
  displayName: 'Account A',
  role: 'owner',
);
const _accountB = AccountSummary(
  id: 'account-b',
  kind: AccountKind.business,
  displayName: 'Account B',
  role: 'owner',
);

void main() {
  test('page parser keeps a deterministic lookahead and enforces account', () {
    final page = moneyEventsPageFromRows(
      accountId: _accountA.id,
      offset: 50,
      pageSize: 2,
      rows: [
        _eventJson('a-3', _accountA.id, minute: 3),
        _eventJson('a-2', _accountA.id, minute: 2),
        _eventJson('a-1', _accountA.id, minute: 1),
      ],
    );

    expect(page.events.map((event) => event.id), ['a-3', 'a-2']);
    expect(page.nextOffset, 52);
    expect(page.hasMore, isTrue);

    expect(
      () => moneyEventsPageFromRows(
        accountId: _accountA.id,
        offset: 0,
        pageSize: 2,
        rows: [_eventJson('b-1', _accountB.id)],
      ),
      throwsStateError,
    );
  });

  test('load more deduplicates a repeated page boundary', () async {
    final loader = _FakeMoneyEventsPageLoader((
      accountId,
      offset,
      pageSize,
    ) async {
      expect(accountId, _accountA.id);
      expect(pageSize, moneyEventsPageSize);
      if (offset == 0) {
        return MoneyEventsPage(
          events: [
            _event('a-3', _accountA.id, minute: 3),
            _event('a-2', _accountA.id, minute: 2),
          ],
          nextOffset: 2,
          hasMore: true,
        );
      }
      expect(offset, 2);
      return MoneyEventsPage(
        events: [
          _event('a-2', _accountA.id, minute: 2),
          _event('a-1', _accountA.id, minute: 1),
        ],
        nextOffset: 4,
        hasMore: false,
      );
    });
    final container = _providerContainer(loader);
    final subscription = container.listen(moneyEventsProvider, (_, _) {});
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    final initial = await container.read(moneyEventsProvider.future);
    expect(initial.events.map((event) => event.id), ['a-3', 'a-2']);

    await container.read(moneyEventsProvider.notifier).loadMore();
    final loaded = container.read(moneyEventsProvider).value!;

    expect(loaded.events.map((event) => event.id), ['a-3', 'a-2', 'a-1']);
    expect(loaded.hasMore, isFalse);
    expect(loader.calls.map((call) => call.offset), [0, 2]);
  });

  test(
    'account change resets paging and ignores an older in-flight page',
    () async {
      final oldAccountPage = Completer<MoneyEventsPage>();
      final loader = _FakeMoneyEventsPageLoader((accountId, offset, _) async {
        if (accountId == _accountA.id && offset == 0) {
          return MoneyEventsPage(
            events: [_event('a-2', _accountA.id)],
            nextOffset: 1,
            hasMore: true,
          );
        }
        if (accountId == _accountA.id && offset == 1) {
          return oldAccountPage.future;
        }
        expect(accountId, _accountB.id);
        expect(offset, 0);
        return MoneyEventsPage(
          events: [_event('b-1', _accountB.id)],
          nextOffset: 1,
          hasMore: false,
        );
      });
      final container = _providerContainer(loader);
      final subscription = container.listen(moneyEventsProvider, (_, _) {});
      addTearDown(subscription.close);
      addTearDown(container.dispose);

      await container.read(moneyEventsProvider.future);
      final oldLoad = container.read(moneyEventsProvider.notifier).loadMore();
      await container.pump();

      container.read(activeAccountProvider.notifier).select(_accountB);
      await container.pump();
      final switched = await container.read(moneyEventsProvider.future);

      expect(switched.accountId, _accountB.id);
      expect(switched.events.map((event) => event.id), ['b-1']);

      oldAccountPage.complete(
        MoneyEventsPage(
          events: [_event('a-1', _accountA.id)],
          nextOffset: 2,
          hasMore: false,
        ),
      );
      await oldLoad;

      final finalState = container.read(moneyEventsProvider).value!;
      expect(finalState.accountId, _accountB.id);
      expect(finalState.events.map((event) => event.id), ['b-1']);
      expect(loader.calls.map((call) => (call.accountId, call.offset)), [
        (_accountA.id, 0),
        (_accountA.id, 1),
        (_accountB.id, 0),
      ]);
    },
  );

  testWidgets('load-more error is visible and retry preserves history', (
    tester,
  ) async {
    var loadMoreAttempts = 0;
    final loader = _FakeMoneyEventsPageLoader((accountId, offset, _) async {
      if (offset == 0) {
        return MoneyEventsPage(
          events: [_event('a-2', accountId, description: 'Newest event')],
          nextOffset: 1,
          hasMore: true,
        );
      }
      loadMoreAttempts++;
      if (loadMoreAttempts == 1) throw StateError('temporary failure');
      return MoneyEventsPage(
        events: [_event('a-1', accountId, description: 'Older event')],
        nextOffset: 2,
        hasMore: false,
      );
    });
    await _pumpMoneyScreen(tester, loader);

    await tester.scrollUntilVisible(
      find.text('Load more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Newest event'), findsOneWidget);
    expect(
      find.text(
        'Could not load more history. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Newest event'), findsOneWidget);
    expect(find.text('Older event'), findsOneWidget);
    expect(find.text('All history loaded.'), findsOneWidget);
    expect(loadMoreAttempts, 2);
  });

  testWidgets('initial history error exposes retry and then recovers', (
    tester,
  ) async {
    var attempts = 0;
    final loader = _FakeMoneyEventsPageLoader((accountId, offset, _) async {
      expect(offset, 0);
      attempts++;
      if (attempts == 1) throw StateError('temporary failure');
      return MoneyEventsPage(
        events: [_event('a-1', accountId, description: 'Recovered event')],
        nextOffset: 1,
        hasMore: false,
      );
    });
    await _pumpMoneyScreen(tester, loader);

    expect(
      find.text('Something went wrong. Check your connection and try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered event'), findsOneWidget);
    expect(attempts, 2);
  });
}

ProviderContainer _providerContainer(_FakeMoneyEventsPageLoader loader) {
  return ProviderContainer(
    overrides: [
      activeAccountProvider.overrideWith(
        () => _TestActiveAccountNotifier(_accountA),
      ),
      moneyEventsPageLoaderProvider.overrideWithValue(loader),
    ],
  );
}

Future<void> _pumpMoneyScreen(
  WidgetTester tester,
  _FakeMoneyEventsPageLoader loader,
) async {
  final container = ProviderContainer(
    overrides: [
      activeAccountProvider.overrideWith(
        () => _TestActiveAccountNotifier(_accountA),
      ),
      moneyEventsPageLoaderProvider.overrideWithValue(loader),
      moneyTotalsProvider.overrideWith((ref) async => MoneyTotals.zero),
      currentProfileProvider.overrideWith((ref) async => null),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MoneyScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _eventJson(
  String id,
  String accountId, {
  int minute = 0,
  String? description,
}) {
  return {
    'id': id,
    'account_id': accountId,
    'item_id': null,
    'kind': 'earn',
    'amount_cents': 100,
    'currency': 'USD',
    'occurred_at': DateTime.utc(2026, 1, 1, 0, minute).toIso8601String(),
    'source_type': 'manual',
    'source_id': null,
    'description': description ?? id,
  };
}

MoneyEvent _event(
  String id,
  String accountId, {
  int minute = 0,
  String? description,
}) {
  return MoneyEvent.fromJson(
    _eventJson(id, accountId, minute: minute, description: description),
  );
}

typedef _LoadPage =
    Future<MoneyEventsPage> Function(
      String accountId,
      int offset,
      int pageSize,
    );

class _FakeMoneyEventsPageLoader implements MoneyEventsPageLoader {
  _FakeMoneyEventsPageLoader(this._loadPage);

  final _LoadPage _loadPage;
  final calls = <({String accountId, int offset, int pageSize})>[];

  @override
  Future<MoneyEventsPage> loadPage({
    required String accountId,
    required int offset,
    required int pageSize,
  }) {
    calls.add((accountId: accountId, offset: offset, pageSize: pageSize));
    return _loadPage(accountId, offset, pageSize);
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
