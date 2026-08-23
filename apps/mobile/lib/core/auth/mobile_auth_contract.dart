/// Canonical mobile callback contract for every Supabase Auth flow in LOOP.
///
/// Android, iOS, Supabase's redirect allow-list, and every auth call must use
/// this exact URI. Keeping the callback in one dependency-free class also lets
/// us test callback acceptance without starting Flutter or Supabase.
class MobileAuthContract {
  const MobileAuthContract._();

  // URI schemes follow RFC 3986 and cannot contain underscores. The Android
  // application id remains com.loop.app.loop_mobile; the callback scheme is
  // deliberately a standards-valid sibling identifier.
  static const callbackScheme = 'com.loop.app.loop-mobile';
  static const callbackHost = 'app';
  static const callbackPath = '/login-callback';
  static const callbackUrl = '$callbackScheme://$callbackHost$callbackPath';

  static const _authResultKeys = <String>{
    'code',
    'error',
    'error_code',
    'error_description',
    'type',
  };

  static const _authResultMarkers = <String>{
    'code',
    'error',
    'error_code',
    'error_description',
  };

  static const _sensitiveTokenKeys = <String>{
    'access_token',
    'refresh_token',
    'provider_token',
    'provider_refresh_token',
    'id_token',
  };

  /// Whether [uri] is the exact PKCE callback that Supabase Flutter may
  /// exchange for a session.
  ///
  /// LOOP uses PKCE, so callbacks carrying bearer tokens in the URL are
  /// rejected. This prevents an unrelated deep link containing a generic
  /// `code` parameter from being treated as authentication and keeps token
  /// material out of custom-URI fragments.
  static bool shouldHandleCallback(Uri uri) {
    if (uri.scheme != callbackScheme ||
        uri.host != callbackHost ||
        uri.path != callbackPath ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }

    final keys = uri.queryParametersAll.keys.toSet();
    if (keys.any(_sensitiveTokenKeys.contains)) return false;
    if (keys.any((key) => !_authResultKeys.contains(key))) return false;

    return keys.any(_authResultMarkers.contains);
  }

  /// Authenticated state is accepted only when Supabase's restored session
  /// and current-user view agree on the same non-empty user id.
  static bool hasConsistentSession({
    required String? sessionUserId,
    required String? currentUserId,
  }) {
    return sessionUserId != null &&
        sessionUserId.isNotEmpty &&
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        sessionUserId == currentUserId;
  }
}
