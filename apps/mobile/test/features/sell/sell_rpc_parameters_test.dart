import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/sell/sell_providers.dart';

void main() {
  test('item photo RPC parameters bind account, item, and object path', () {
    expect(
      buildItemPhotoRpcParameters(
        accountId: 'account-a',
        itemId: 'item-a',
        objectPath: 'account-a/item-a/photo.jpg',
      ),
      {
        'p_account_id': 'account-a',
        'p_item_id': 'item-a',
        'p_object_path': 'account-a/item-a/photo.jpg',
      },
    );
  });
}
