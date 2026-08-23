import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/user_safe_error.dart';
import 'models/item.dart';
import 'models/listing.dart';
import 'models/valuation.dart';

const itemPhotosBucket = 'item-photos';
const _signedUrlTtlSeconds = 60 * 60; // 1 hour — regenerated every fetch

Map<String, dynamic> buildListingRpcParameters({
  required String accountId,
  required String itemId,
  required String marketplace,
  int? listPriceCents,
}) {
  return {
    'p_account_id': accountId,
    'p_item_id': itemId,
    'p_marketplace': marketplace,
    'p_list_price_cents': listPriceCents,
  };
}

Map<String, dynamic> buildSaleRpcParameters({
  required String accountId,
  required String itemId,
  String? listingId,
  required int salePriceCents,
  required int feesCents,
}) {
  return {
    'p_account_id': accountId,
    'p_item_id': itemId,
    'p_listing_id': listingId,
    'p_sale_price_cents': salePriceCents,
    'p_fees_cents': feesCents,
  };
}

Map<String, dynamic> buildItemPhotoRpcParameters({
  required String accountId,
  required String itemId,
  required String objectPath,
}) {
  return {
    'p_account_id': accountId,
    'p_item_id': itemId,
    'p_object_path': objectPath,
  };
}

class SellPageData {
  const SellPageData({
    required this.items,
    required this.latestValuationByItem,
    required this.listingsByItem,
    required this.signedUrlByPath,
  });

  final List<Item> items;
  final Map<String, ValuationRow> latestValuationByItem;
  final Map<String, List<ListingRow>> listingsByItem;

  /// Storage object path -> short-lived signed URL. The bucket is private,
  /// so every photo path is resolved to a fresh signed URL on each fetch
  /// rather than stored/cached as a permanent link — mirrors
  /// `apps/web/src/app/(app)/sell/page.tsx`'s `signedUrlByPath`.
  final Map<String, String> signedUrlByPath;
}

/// Items + latest valuation per item + open (draft/active) listings per
/// item, for the active account — mirrors the parallel fetch in
/// `apps/web/src/app/(app)/sell/page.tsx`.
final sellPageProvider = FutureProvider.autoDispose<SellPageData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  if (accountId.isEmpty) {
    return const SellPageData(
      items: [],
      latestValuationByItem: {},
      listingsByItem: {},
      signedUrlByPath: {},
    );
  }

  final results = await Future.wait([
    client
        .from('items')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false),
    client
        .from('valuations')
        .select('item_id, estimated_value_cents, valued_at')
        .eq('account_id', accountId)
        .order('valued_at', ascending: false),
    client
        .from('listings')
        .select('id, item_id, marketplace, status, list_price_cents')
        .eq('account_id', accountId)
        .inFilter('status', ['draft', 'active']),
  ]);

  final items = (results[0]).map(Item.fromJson).toList();
  final valuations = (results[1]).map(ValuationRow.fromJson).toList();
  final listings = (results[2]).map(ListingRow.fromJson).toList();

  final latestValuationByItem = <String, ValuationRow>{};
  for (final v in valuations) {
    latestValuationByItem.putIfAbsent(v.itemId, () => v);
  }

  final listingsByItem = <String, List<ListingRow>>{};
  for (final l in listings) {
    (listingsByItem[l.itemId] ??= []).add(l);
  }

  final allPhotoPaths = items.expand((item) => item.photos).toList();
  final signedUrlByPath = <String, String>{};
  if (allPhotoPaths.isNotEmpty) {
    final signed = await client.storage
        .from(itemPhotosBucket)
        .createSignedUrlsResult(allPhotoPaths, _signedUrlTtlSeconds);
    for (final entry in signed) {
      if (entry is SignedUrlSuccess) {
        signedUrlByPath[entry.path] = entry.signedUrl;
      }
    }
  }

  return SellPageData(
    items: items,
    latestValuationByItem: latestValuationByItem,
    listingsByItem: listingsByItem,
    signedUrlByPath: signedUrlByPath,
  );
});

class SellRepository {
  SellRepository(this._client);

  final SupabaseClient _client;

  Future<void> createItem({
    required String accountId,
    required String name,
    String? category,
    String? condition,
    int? purchasePriceCents,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('items').insert({
      'account_id': accountId,
      'name': name,
      'category': category,
      'condition': condition,
      'purchase_price_cents': purchasePriceCents,
      'created_by': userId,
    });
  }

  Future<void> addValuation({
    required String accountId,
    required String itemId,
    required int estimatedValueCents,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('valuations').insert({
      'account_id': accountId,
      'item_id': itemId,
      'source': 'manual',
      'estimated_value_cents': estimatedValueCents,
      'created_by': userId,
    });
  }

  Future<void> createListing({
    required String accountId,
    required String itemId,
    required String marketplace,
    int? listPriceCents,
  }) async {
    await _client.rpc(
      'create_listing_and_mark_item',
      params: buildListingRpcParameters(
        accountId: accountId,
        itemId: itemId,
        marketplace: marketplace,
        listPriceCents: listPriceCents,
      ),
    );
  }

  Future<void> recordSale({
    required String accountId,
    required String itemId,
    String? listingId,
    required int salePriceCents,
    int feesCents = 0,
  }) async {
    await _client.rpc(
      'record_item_sale',
      params: buildSaleRpcParameters(
        accountId: accountId,
        itemId: itemId,
        listingId: listingId,
        salePriceCents: salePriceCents,
        feesCents: feesCents,
      ),
    );
  }

  static const _allowedPhotoExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };
  static const _maxPhotoBytes = 8 * 1024 * 1024;

  /// Opens the system photo picker, uploads the chosen image directly to
  /// the private `item-photos` Storage bucket (RLS-scoped by
  /// `has_account_access` — see
  /// supabase/migrations/20260822145553_item_photos_storage.sql), and
  /// atomically appends the resulting object path to `items.photos`. Mirrors
  /// `AddPhotoControl` in
  /// apps/web/src/app/(app)/sell/item-actions.tsx control-for-control.
  /// Returns null if the user cancelled the picker, or an error message.
  Future<String?> pickAndUploadPhoto({
    required String accountId,
    required String itemId,
  }) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final ext = picked.name.split('.').last.toLowerCase();
    if (!_allowedPhotoExtensions.contains(ext)) {
      return 'Use a JPEG, PNG, WEBP, or HEIC image.';
    }

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > _maxPhotoBytes) {
      return 'Photo must be 8MB or smaller.';
    }

    final objectPath =
        '$accountId/$itemId/${DateTime.now().microsecondsSinceEpoch}.$ext';

    try {
      await _client.storage
          .from(itemPhotosBucket)
          .uploadBinary(objectPath, bytes);
    } catch (_) {
      return userSafeActionError('upload this photo');
    }

    try {
      await _client.rpc(
        'attach_item_photo',
        params: buildItemPhotoRpcParameters(
          accountId: accountId,
          itemId: itemId,
          objectPath: objectPath,
        ),
      );
      return null;
    } catch (_) {
      try {
        await _client.storage.from(itemPhotosBucket).remove([objectPath]);
      } catch (_) {
        // The upload is private and account-scoped. A later cleanup can remove
        // an orphan if the network also failed during this best-effort rollback.
      }
      return userSafeActionError('save this photo');
    }
  }

  Future<void> removePhoto({
    required String accountId,
    required String itemId,
    required String objectPath,
  }) async {
    final params = buildItemPhotoRpcParameters(
      accountId: accountId,
      itemId: itemId,
      objectPath: objectPath,
    );
    await _client.rpc('detach_item_photo', params: params);
    try {
      await _client.storage.from(itemPhotosBucket).remove([objectPath]);
    } catch (error, stackTrace) {
      // Restore only this path. The atomic RPC preserves any concurrent photo
      // changes instead of writing back a stale whole-array snapshot.
      try {
        await _client.rpc('attach_item_photo', params: params);
      } catch (_) {
        // Keep reporting the original Storage failure. The guarded attach RPC
        // refuses to recreate metadata for an object that is already gone.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final sellRepositoryProvider = Provider<SellRepository>((ref) {
  return SellRepository(ref.watch(supabaseClientProvider));
});
