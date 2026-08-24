import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/account_context.dart';
import 'package:loop_mobile/core/account/account_providers.dart';
import 'package:loop_mobile/features/ai/ai_repository.dart';
import 'package:loop_mobile/features/ai/ai_screen.dart';

const _personal = AccountSummary(
  id: 'account-a',
  kind: AccountKind.personal,
  displayName: 'Personal',
);
const _business = AccountSummary(
  id: 'account-b',
  kind: AccountKind.business,
  displayName: 'Studio',
  role: 'owner',
);

void main() {
  testWidgets('account switch clears a pending AI confirmation', (
    tester,
  ) async {
    final gateway = _FakeAiGateway();
    final container = ProviderContainer(
      overrides: [
        activeAccountProvider.overrideWith(
          () => _TestActiveAccountNotifier(_personal),
        ),
        availableAccountsProvider.overrideWith(
          (ref) async => const [_personal, _business],
        ),
        aiGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Add a follow-up');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    gateway.completeSend(_confirmation());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('LOOP wants to create an action'),
      findsOneWidget,
    );

    container.read(activeAccountProvider.notifier).select(_business);
    await tester.pumpAndSettle();

    expect(find.textContaining('LOOP wants to create an action'), findsNothing);
    expect(find.text('Ask LOOP'), findsWidgets);
    expect(
      find.text('This action was created for another account. Ask LOOP again.'),
      findsOneWidget,
    );
  });

  testWidgets('an old account response is ignored after an account switch', (
    tester,
  ) async {
    final gateway = _FakeAiGateway();
    final container = ProviderContainer(
      overrides: [
        activeAccountProvider.overrideWith(
          () => _TestActiveAccountNotifier(_personal),
        ),
        availableAccountsProvider.overrideWith(
          (ref) async => const [_personal, _business],
        ),
        aiGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Add a follow-up');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    container.read(activeAccountProvider.notifier).select(_business);
    await tester.pump();
    gateway.completeSend(_confirmation());
    await tester.pumpAndSettle();

    expect(find.textContaining('LOOP wants to create an action'), findsNothing);
    expect(find.text('Ask LOOP'), findsWidgets);
  });

  testWidgets(
    'unexpected gateway failure clears loading and remains retryable',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWith(
            () => _TestActiveAccountNotifier(_personal),
          ),
          availableAccountsProvider.overrideWith(
            (ref) async => const [_personal],
          ),
          aiGatewayProvider.overrideWithValue(_ThrowingAiGateway()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AiScreen()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Add a follow-up');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('LOOP hit an unexpected problem. Try again.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Retry'))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('LOOP hit an unexpected problem. Try again.'),
        findsOneWidget,
      );
    },
  );
}

ChatToolConfirmation _confirmation() => const ChatToolConfirmation(
  toolUseId: 'tool-a',
  toolName: 'create_action',
  input: {'title': 'Follow up'},
  confirmationToken: 'signed-token',
  messages: [],
);

class _FakeAiGateway implements AiGateway {
  final Completer<ChatResponse> _send = Completer<ChatResponse>();

  void completeSend(ChatResponse response) => _send.complete(response);

  @override
  Future<ChatResponse> sendMessage({
    required List<dynamic> messages,
    required String accountId,
  }) => _send.future;

  @override
  Future<ChatResponse> confirmTool({
    required List<dynamic> messages,
    required String toolUseId,
    required String confirmationToken,
    required bool approve,
    required String accountId,
  }) async => const ChatTextResponse(text: 'Done', messages: []);
}

class _ThrowingAiGateway implements AiGateway {
  @override
  Future<ChatResponse> sendMessage({
    required List<dynamic> messages,
    required String accountId,
  }) => Future<ChatResponse>.error(StateError('synthetic gateway failure'));

  @override
  Future<ChatResponse> confirmTool({
    required List<dynamic> messages,
    required String toolUseId,
    required String confirmationToken,
    required bool approve,
    required String accountId,
  }) => Future<ChatResponse>.error(StateError('synthetic gateway failure'));
}

class _TestActiveAccountNotifier extends ActiveAccountNotifier {
  _TestActiveAccountNotifier(this.initial);

  final AccountSummary initial;

  @override
  AccountSummary build() => initial;

  @override
  void select(AccountSummary account) => state = account;
}
