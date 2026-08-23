import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/money/purchases/purchases_providers.dart';
import 'package:loop_mobile/features/sell/sell_providers.dart';

void main() {
  test('purchase and refund parameters match the hosted RPC contract', () {
    expect(
      buildPurchaseRpcParameters(
        accountId: 'account',
        itemId: 'item',
        vendorName: 'Store',
        purchaseDate: '2026-08-01',
        priceCents: 2500,
        returnWindowExpiresAt: '2026-08-31',
        warrantyExpiresAt: '2027-08-01',
      ),
      {
        'p_account_id': 'account',
        'p_item_id': 'item',
        'p_vendor_name': 'Store',
        'p_purchase_date': '2026-08-01',
        'p_price_cents': 2500,
        'p_return_window_expires_at': '2026-08-31',
        'p_warranty_expires_at': '2027-08-01',
      },
    );
    expect(
      buildRefundRpcParameters(
        accountId: 'account',
        returnId: 'return',
        itemId: 'item',
        refundAmountCents: 700,
      ),
      {
        'p_account_id': 'account',
        'p_return_id': 'return',
        'p_item_id': 'item',
        'p_refund_amount_cents': 700,
      },
    );
  });

  test('listing and sale parameters match the hosted RPC contract', () {
    expect(
      buildListingRpcParameters(
        accountId: 'account',
        itemId: 'item',
        marketplace: 'Market',
        listPriceCents: 1200,
      ),
      {
        'p_account_id': 'account',
        'p_item_id': 'item',
        'p_marketplace': 'Market',
        'p_list_price_cents': 1200,
      },
    );
    expect(
      buildSaleRpcParameters(
        accountId: 'account',
        itemId: 'item',
        listingId: 'listing',
        salePriceCents: 1000,
        feesCents: 100,
      ),
      {
        'p_account_id': 'account',
        'p_item_id': 'item',
        'p_listing_id': 'listing',
        'p_sale_price_cents': 1000,
        'p_fees_cents': 100,
      },
    );
  });
}
