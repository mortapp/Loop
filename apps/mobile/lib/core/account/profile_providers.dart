import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';

/// The signed-in user's own `profiles` row — mirrors
/// apps/web/src/lib/profile.ts's `getCurrentProfile`.
class Profile {
  const Profile({required this.id, required this.email, this.displayName});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
    );
  }

  final String id;
  final String email;
  final String? displayName;
}

/// Deterministic initials from a display name or email — never a random
/// color/glyph per launch. Mirrors apps/web's `initialsFor`.
String initialsFor(String? displayName, String email) {
  final source = (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : email;
  final parts = source
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return source
      .substring(0, source.length < 2 ? source.length : 2)
      .toUpperCase();
}

final currentProfileProvider = FutureProvider.autoDispose<Profile?>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final row = await client
      .from('profiles')
      .select('id, email, display_name')
      .eq('id', userId)
      .single();
  return Profile.fromJson(row);
});

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<void> updateDisplayName(String userId, String displayName) {
    return _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', userId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
