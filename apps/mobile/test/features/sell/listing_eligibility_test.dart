import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/sell/models/item.dart';

void main() {
  group('canPrepareListing / canRecordSale', () {
    test('owned and listed items are sellable', () {
      expect(canPrepareListing(ItemStatus.owned), isTrue);
      expect(canPrepareListing(ItemStatus.listed), isTrue);
      expect(canRecordSale(ItemStatus.owned), isTrue);
      expect(canRecordSale(ItemStatus.listed), isTrue);
    });

    test('returned, sold, and disposed items are not sellable', () {
      // Mirrors the server guard in
      // 20260823060632_enforce_atomic_money_lifecycle.sql, which rejects
      // any item status outside ('owned', 'listed'). A returned/disposed
      // item is not `sold`, so a `status != sold` check alone would
      // wrongly permit it.
      for (final status in [
        ItemStatus.returned,
        ItemStatus.sold,
        ItemStatus.disposed,
      ]) {
        expect(canPrepareListing(status), isFalse, reason: status.name);
        expect(canRecordSale(status), isFalse, reason: status.name);
      }
    });
  });
}
