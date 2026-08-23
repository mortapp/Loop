import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';

String slugifyBusinessName(String name) {
  final slug = name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-|-$)+'), '');
  return slug.isEmpty ? 'business' : slug;
}

class BusinessRepository {
  BusinessRepository(this._client);

  final SupabaseClient _client;

  Future<String> createBusiness(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not signed in.');

    final suffix = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    final business = await _client
        .from('businesses')
        .insert({
          'name': name,
          'slug': '${slugifyBusinessName(name)}-$suffix',
          'created_by': userId,
        })
        .select('id')
        .single();

    final account = await _client
        .from('accounts')
        .select('id')
        .eq('business_id', business['id'] as String)
        .single();
    return account['id'] as String;
  }
}

final businessRepositoryProvider = Provider<BusinessRepository>(
  (ref) => BusinessRepository(ref.watch(supabaseClientProvider)),
);

final businessCreatorProvider = Provider<Future<String> Function(String)>(
  (ref) => ref.watch(businessRepositoryProvider).createBusiness,
);
