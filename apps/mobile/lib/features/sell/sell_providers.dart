import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import 'models/item.dart';
import 'models/listing.dart';
import 'models/valuation.dart';

const itemPhotosBucket = 'item-photos';
const _signedUrlTtlSeconds = 60 * 60; // 1 hour — regenerated every fetch

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
    final userId = _client.auth.currentUser?.id;
    await _client.from('listings').insert({
      'account_id': accountId,
      'item_id': itemId,
      'marketplace': marketplace,
      'status': 'active',
      'list_price_cents': listPriceCents,
      'published_at': DateTime.now().toIso8601String(),
      'created_by': userId,
    });

    await _client.from('items').update({'status': 'listed'}).eq('id', itemId);
  }

  Future<void> recordSale({
    required String accountId,
    required String itemId,
    String? listingId,
    required int salePriceCents,
    int feesCents = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final netAmountCents = salePriceCents - feesCents;

    await _client.from('sales').insert({
      'account_id': accountId,
      'item_id': itemId,
      'listing_id': listingId,
      'sale_price_cents': salePriceCents,
      'fees_cents': feesCents,
      'net_amount_cents': netAmountCents,
      'created_by': userId,
    });

    await _client.from('items').update({'status': 'sold'}).eq('id', itemId);
    if (listingId != null) {
      await _client
          .from('listings')
          .update({'status': 'sold'})
          .eq('id', listingId);
    }

    await _client.from('money_events').insert({
      'account_id': accountId,
      'item_id': itemId,
      'kind': 'recovered',
      'amount_cents': netAmountCents,
      'source_type': 'sale',
      'description': 'Item sold via RECOVER',
      'created_by': userId,
    });
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
  /// appends the resulting object path to `items.photos`. Mirrors
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
    } catch (e) {
      return 'Upload failed: $e';
    }

    try {
      final row = await _client
          .from('items')
          .select('photos')
          .eq('id', itemId)
          .single();
      final photos = ((row['photos'] as List<dynamic>?) ?? []).cast<String>();
      await _client
          .from('items')
          .update({
            'photos': [...photos, objectPath],
          })
          .eq('id', itemId);
      return null;
    } catch (e) {
      await _client.storage.from(itemPhotosBucket).remove([objectPath]);
      return 'Failed to save photo: $e';
    }
  }

  Future<void> removePhoto({
    required String itemId,
    required String objectPath,
  }) async {
    final row = await _client
        .from('items')
        .select('photos')
        .eq('id', itemId)
        .single();
    final photos = ((row['photos'] as List<dynamic>?) ?? [])
        .cast<String>()
        .where((p) => p != objectPath)
        .toList();
    await _client.from('items').update({'photos': photos}).eq('id', itemId);
    await _client.storage.from(itemPhotosBucket).remove([objectPath]);
  }
}

final sellRepositoryProvider = Provider<SellRepository>((ref) {
  return SellRepository(ref.watch(supabaseClientProvider));
});
