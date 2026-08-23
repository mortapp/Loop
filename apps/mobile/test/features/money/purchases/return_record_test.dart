import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/money/purchases/models/return_record.dart';

void main() {
  test('return status choices only move forward', () {
    expect(nextReturnStatuses(ReturnStatus.initiated), [
      ReturnStatus.shipped,
      ReturnStatus.received,
      ReturnStatus.denied,
    ]);
    expect(nextReturnStatuses(ReturnStatus.shipped), [
      ReturnStatus.received,
      ReturnStatus.denied,
    ]);
    expect(nextReturnStatuses(ReturnStatus.received), [ReturnStatus.denied]);
    expect(nextReturnStatuses(ReturnStatus.refunded), isEmpty);
    expect(nextReturnStatuses(ReturnStatus.denied), isEmpty);
  });
}
