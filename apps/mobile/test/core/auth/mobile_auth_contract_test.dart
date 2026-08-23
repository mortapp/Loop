import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/auth/mobile_auth_contract.dart';

void main() {
  group('MobileAuthContract.shouldHandleCallback', () {
    test('accepts the exact PKCE callback with an authorization code', () {
      final uri = Uri.parse(
        '${MobileAuthContract.callbackUrl}?code=one-time-code',
      );

      expect(MobileAuthContract.shouldHandleCallback(uri), isTrue);
    });

    test('accepts an exact callback carrying a safe OAuth error', () {
      final uri = Uri.parse(
        '${MobileAuthContract.callbackUrl}?error=access_denied'
        '&error_description=cancelled',
      );

      expect(MobileAuthContract.shouldHandleCallback(uri), isTrue);
    });

    test('the legacy underscore callback is not a valid URI', () {
      expect(
        Uri.tryParse(
          'com.loop.app.loop_mobile://login-callback?code=one-time-code',
        ),
        isNull,
      );
    });

    test('rejects another route even when it contains code', () {
      final uri = Uri.parse(
        'com.loop.app.loop-mobile://app/other?code=one-time-code',
      );

      expect(MobileAuthContract.shouldHandleCallback(uri), isFalse);
    });

    test('rejects callbacks carrying bearer tokens', () {
      final queryToken = Uri.parse(
        '${MobileAuthContract.callbackUrl}?access_token=secret',
      );
      final fragmentToken = Uri.parse(
        '${MobileAuthContract.callbackUrl}#access_token=secret',
      );

      expect(MobileAuthContract.shouldHandleCallback(queryToken), isFalse);
      expect(MobileAuthContract.shouldHandleCallback(fragmentToken), isFalse);
    });

    test('rejects links without an auth result marker', () {
      expect(
        MobileAuthContract.shouldHandleCallback(
          Uri.parse(MobileAuthContract.callbackUrl),
        ),
        isFalse,
      );
    });

    test('rejects unexpected callback parameters', () {
      final uri = Uri.parse(
        '${MobileAuthContract.callbackUrl}?code=one-time-code&next=/today',
      );

      expect(MobileAuthContract.shouldHandleCallback(uri), isFalse);
    });
  });

  group('MobileAuthContract.hasConsistentSession', () {
    test('accepts matching non-empty user ids', () {
      expect(
        MobileAuthContract.hasConsistentSession(
          sessionUserId: 'user-1',
          currentUserId: 'user-1',
        ),
        isTrue,
      );
    });

    test('rejects missing, empty, and mismatched user ids', () {
      expect(
        MobileAuthContract.hasConsistentSession(
          sessionUserId: null,
          currentUserId: null,
        ),
        isFalse,
      );
      expect(
        MobileAuthContract.hasConsistentSession(
          sessionUserId: '',
          currentUserId: '',
        ),
        isFalse,
      );
      expect(
        MobileAuthContract.hasConsistentSession(
          sessionUserId: 'user-1',
          currentUserId: 'user-2',
        ),
        isFalse,
      );
    });
  });
}
