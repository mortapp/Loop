import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/sell/listing_text.dart';
import 'package:loop_mobile/features/sell/models/item.dart';
import 'package:loop_mobile/features/sell/models/listing.dart';
import 'package:loop_mobile/features/sell/models/valuation.dart';

Item _item({
  String id = 'item-a',
  String accountId = 'account-a',
  String name = 'Vintage lamp',
  String? category = 'Home',
  String? condition = 'Excellent',
  ItemStatus status = ItemStatus.owned,
}) {
  return Item(
    id: id,
    accountId: accountId,
    name: name,
    category: category,
    condition: condition,
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('buildListingText', () {
    test('includes name, details, and an active listing price', () {
      final text = buildListingText(
        item: _item(),
        listings: const [
          ListingRow(
            id: 'listing-a',
            itemId: 'item-a',
            marketplace: 'Facebook Marketplace',
            status: ListingStatus.active,
            listPriceCents: 4599,
          ),
        ],
      );

      expect(text, contains('Vintage lamp'));
      expect(text, contains('Home · Excellent'));
      expect(text, contains(r'$45.99'));
      expect(text, contains('Facebook Marketplace'));
    });

    test('falls back to the latest valuation when nothing is listed', () {
      final text = buildListingText(
        item: _item(),
        valuation: ValuationRow(
          itemId: 'item-a',
          estimatedValueCents: 2500,
          valuedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(text, contains(r'Estimated value $25.00'));
    });

    test('never includes ids, account ids, or storage paths', () {
      final text = buildListingText(
        item: _item(id: 'item-secret-id', accountId: 'account-secret-id'),
        listings: const [
          ListingRow(
            id: 'listing-secret-id',
            itemId: 'item-secret-id',
            marketplace: 'eBay',
            status: ListingStatus.draft,
            listPriceCents: 1000,
          ),
        ],
      );

      expect(text, isNot(contains('item-secret-id')));
      expect(text, isNot(contains('account-secret-id')));
      expect(text, isNot(contains('listing-secret-id')));
    });
  });
}
