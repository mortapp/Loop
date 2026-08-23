import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/account/account_context.dart';
import 'package:loop_mobile/core/account/account_providers.dart';

void main() {
  const personal = AccountSummary(
    id: 'personal',
    kind: AccountKind.personal,
    displayName: 'Personal',
  );
  const business = AccountSummary(
    id: 'business',
    kind: AccountKind.business,
    displayName: 'Studio',
    role: 'owner',
  );

  test('active selection survives an account-list refresh', () {
    expect(
      resolveActiveAccount([personal, business], 'business'),
      same(business),
    );
  });

  test('removed selections fall back and empty lists stay unresolved', () {
    expect(resolveActiveAccount([personal], 'business'), same(personal));
    expect(resolveActiveAccount(const [], 'business'), isNull);
  });
}
