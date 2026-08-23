import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/business/quotes/quotes_providers.dart';

void main() {
  group('buildCreateQuoteRpcParameters', () {
    test('builds one atomic RPC payload and calculates totals', () {
      final parameters = buildCreateQuoteRpcParameters(
        accountId: '11111111-1111-4111-8111-111111111111',
        contactId: '22222222-2222-4222-8222-222222222222',
        opportunityId: null,
        userId: '33333333-3333-4333-8333-333333333333',
        quoteNumber: 'Q-TEST',
        lines: const [
          PreparedLine(
            description: '  Design work  ',
            quantity: 1.5,
            unitPriceCents: 2000,
          ),
          PreparedLine(
            description: 'Materials',
            quantity: 2,
            unitPriceCents: 250,
          ),
        ],
      );

      expect(parameters['p_subtotal_cents'], 3500);
      expect(parameters['p_tax_cents'], 0);
      expect(parameters['p_total_cents'], 3500);
      expect(
        parameters['p_created_by'],
        '33333333-3333-4333-8333-333333333333',
      );
      expect(parameters['p_line_items'], [
        {
          'description': 'Design work',
          'quantity': 1.5,
          'unit_price_cents': 2000,
        },
        {'description': 'Materials', 'quantity': 2.0, 'unit_price_cents': 250},
      ]);
    });

    test('rejects an empty quote', () {
      expect(
        () => buildCreateQuoteRpcParameters(
          accountId: 'account',
          contactId: 'contact',
          opportunityId: null,
          userId: 'user',
          quoteNumber: 'Q-TEST',
          lines: const [],
        ),
        throwsStateError,
      );
    });

    test('rejects non-finite quantities and negative prices', () {
      for (final line in [
        const PreparedLine(
          description: 'Bad quantity',
          quantity: double.infinity,
          unitPriceCents: 100,
        ),
        const PreparedLine(
          description: 'Bad price',
          quantity: 1,
          unitPriceCents: -1,
        ),
      ]) {
        expect(
          () => buildCreateQuoteRpcParameters(
            accountId: 'account',
            contactId: 'contact',
            opportunityId: null,
            userId: 'user',
            quoteNumber: 'Q-TEST',
            lines: [line],
          ),
          throwsStateError,
        );
      }
    });
  });
}
