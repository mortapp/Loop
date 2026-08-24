import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/utils/request_id.dart';

void main() {
  test('newRequestId creates deterministic RFC 4122 version 4 identities', () {
    final first = newRequestId(random: Random(42));
    final repeated = newRequestId(random: Random(42));

    expect(first, repeated);
    expect(isRequestId(first), isTrue);
    expect(first[14], '4');
    expect('89ab', contains(first[19]));
  });

  test('newRequestId advances to a new identity for the next mutation', () {
    final random = Random(42);

    expect(newRequestId(random: random), isNot(newRequestId(random: random)));
  });
}
