import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/account_context.dart';
import 'package:loop_mobile/core/account/account_providers.dart';
import 'package:loop_mobile/features/business/contacts/contacts_providers.dart';
import 'package:loop_mobile/features/business/contacts/models/contact.dart';
import 'package:loop_mobile/features/business/opportunities/opportunities_providers.dart';
import 'package:loop_mobile/features/business/quotes/models/quote.dart';
import 'package:loop_mobile/features/business/quotes/quotes_providers.dart';
import 'package:loop_mobile/features/business/quotes/quotes_screen.dart';

const _account = AccountSummary(
  id: 'account-a',
  kind: AccountKind.business,
  displayName: 'Test business',
  role: 'owner',
);

void main() {
  group('prepareQuoteLines', () {
    test('rejects blank, malformed, and non-finite unit prices', () {
      for (final unitPrice in [
        '',
        'not-a-price',
        '1.2.3',
        'NaN',
        'Infinity',
        '-Infinity',
        '1e309',
      ]) {
        final result = prepareQuoteLines([
          QuoteLineDraft(description: 'Consulting', unitPrice: unitPrice),
        ]);

        expect(result.error, isNotNull, reason: 'unit price: $unitPrice');
        expect(result.lines, isEmpty, reason: 'unit price: $unitPrice');
        expect(result.totalCents, isNull, reason: 'unit price: $unitPrice');
      }
    });

    test('preserves an explicitly entered zero unit price', () {
      final result = prepareQuoteLines([
        QuoteLineDraft(
          description: 'Complimentary setup',
          quantity: '2',
          unitPrice: '0.00',
        ),
      ]);

      expect(result.error, isNull);
      expect(result.lines, hasLength(1));
      expect(result.lines.single.unitPriceCents, 0);
      expect(result.totalCents, 0);
    });

    test('calculates a finite total and ignores untouched extra rows', () {
      final result = prepareQuoteLines([
        QuoteLineDraft(
          description: 'Design work',
          quantity: '1.5',
          unitPrice: '12.34',
        ),
        QuoteLineDraft(),
      ]);

      expect(result.error, isNull);
      expect(result.lines, hasLength(1));
      expect(result.lines.single.unitPriceCents, 1234);
      expect(result.totalCents, 1851);
    });
  });

  testWidgets('invalid unit price stays invalid and is never submitted', (
    tester,
  ) async {
    final repository = _RecordingQuotesRepository();
    await _pumpQuotesScreen(tester, repository);
    await _selectContact(tester);

    await tester.enterText(_textFieldWithHint('Description'), 'Consulting');
    await tester.enterText(_textFieldWithHint(r'$/unit'), 'Infinity');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Total: —'), findsOneWidget);

    await tester.ensureVisible(find.text('Create quote'));
    await tester.tap(find.text('Create quote'));
    await tester.pump();

    expect(
      find.text(
        'Line 1: enter a valid non-negative unit price. '
        'Use 0 for a free line item.',
      ),
      findsOneWidget,
    );
    expect(repository.createCalls, 0);
  });

  testWidgets('explicit zero renders and submits as zero cents', (
    tester,
  ) async {
    final repository = _RecordingQuotesRepository();
    await _pumpQuotesScreen(tester, repository);
    await _selectContact(tester);

    await tester.enterText(
      _textFieldWithHint('Description'),
      'Complimentary setup',
    );
    await tester.enterText(_textFieldWithHint(r'$/unit'), '0');
    await tester.pump();

    expect(find.text(r'Total: $0.00'), findsOneWidget);

    await tester.ensureVisible(find.text('Create quote'));
    await tester.tap(find.text('Create quote'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.submittedLines, hasLength(1));
    expect(repository.submittedLines!.single.unitPriceCents, 0);
  });

  testWidgets('removable quote lines expose an accessible control name', (
    tester,
  ) async {
    await _pumpQuotesScreen(tester, _RecordingQuotesRepository());

    await tester.tap(find.text('+ Add line'));
    await tester.pump();

    expect(find.byTooltip('Remove quote line'), findsNWidgets(2));
  });
}

Finder _textFieldWithHint(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

Future<void> _pumpQuotesScreen(
  WidgetTester tester,
  _RecordingQuotesRepository repository,
) async {
  final container = ProviderContainer(
    overrides: [
      activeAccountProvider.overrideWith(
        () => _TestActiveAccountNotifier(_account),
      ),
      quotesProvider.overrideWith((ref) async => const <Quote>[]),
      contactRefsProvider.overrideWith(
        (ref) async => const [
          ContactRef(id: 'contact-a', displayName: 'Test Contact'),
        ],
      ),
      opportunityRefsProvider.overrideWith(
        (ref) async => const <OpportunityRef>[],
      ),
      quotesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: QuotesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectContact(WidgetTester tester) async {
  final contactPicker = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == 'Contact',
  );
  await tester.tap(contactPicker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Contact').last);
  await tester.pumpAndSettle();
}

class _TestActiveAccountNotifier extends ActiveAccountNotifier {
  _TestActiveAccountNotifier(this.initial);

  final AccountSummary initial;

  @override
  AccountSummary build() => initial;
}

class _RecordingQuotesRepository implements QuotesRepository {
  int createCalls = 0;
  List<PreparedLine>? submittedLines;

  @override
  Future<void> createQuote({
    required String accountId,
    required String contactId,
    String? opportunityId,
    required List<PreparedLine> lines,
  }) async {
    createCalls++;
    submittedLines = List<PreparedLine>.of(lines);
  }

  @override
  Future<void> setStatus({
    required String id,
    required QuoteStatus status,
  }) async {}
}
