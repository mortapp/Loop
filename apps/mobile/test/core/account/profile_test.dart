import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/profile_providers.dart';

void main() {
  test('profile onboarding requires both display name and username', () {
    const incompleteName = Profile(
      id: 'user-1',
      email: 'person@example.test',
      username: 'person',
    );
    const incompleteUsername = Profile(
      id: 'user-1',
      email: 'person@example.test',
      displayName: 'Person',
    );
    const complete = Profile(
      id: 'user-1',
      email: 'person@example.test',
      displayName: 'Person',
      username: 'person',
    );

    expect(incompleteName.hasCompletedOnboarding, isFalse);
    expect(incompleteUsername.hasCompletedOnboarding, isFalse);
    expect(complete.hasCompletedOnboarding, isTrue);
  });
}
