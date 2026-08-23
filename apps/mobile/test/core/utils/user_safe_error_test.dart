import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/utils/user_safe_error.dart';

void main() {
  test('mutation copy is actionable and contains no backend details', () {
    final message = userSafeActionError('save this item');

    expect(
      message,
      'Could not save this item. Check your connection and try again.',
    );
    expect(message, isNot(contains('PostgrestException')));
    expect(message, isNot(contains('policy')));
    expect(message, isNot(contains('constraint')));
  });
}
