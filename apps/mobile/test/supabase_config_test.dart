// Regression coverage for the config-contract bug found on the physical
// Galaxy A14: a debug build run without --dart-define reached the Google
// OAuth flow against an unreachable "placeholder.supabase.co" instead of
// failing loudly. `SupabaseConfig.isValidConfig` is what main.dart now
// gates startup on (see lib/main.dart, lib/core/config/
// configuration_error_app.dart) -- these cases must never regress.

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/supabase/supabase_config.dart';

void main() {
  group('SupabaseConfig.isValidConfig', () {
    test('accepts a real https Supabase URL with a non-empty anon key', () {
      expect(
        SupabaseConfig.isValidConfig(
          'https://zqalnvfwxmfrnyjcuehq.supabase.co',
          'a-real-looking-anon-key',
        ),
        isTrue,
      );
    });

    test('rejects a missing (empty) URL', () {
      expect(
        SupabaseConfig.isValidConfig('', 'a-real-looking-anon-key'),
        isFalse,
      );
    });

    test('rejects a missing (empty) anon key', () {
      expect(
        SupabaseConfig.isValidConfig(
          'https://zqalnvfwxmfrnyjcuehq.supabase.co',
          '',
        ),
        isFalse,
      );
    });

    test('rejects both empty', () {
      expect(SupabaseConfig.isValidConfig('', ''), isFalse);
    });

    test(
      'rejects the literal placeholder host -- the exact regression found on the Galaxy A14',
      () {
        expect(
          SupabaseConfig.isValidConfig(
            'https://placeholder.supabase.co',
            'a-real-looking-anon-key',
          ),
          isFalse,
        );
      },
    );

    test('rejects a non-https scheme', () {
      expect(
        SupabaseConfig.isValidConfig(
          'http://zqalnvfwxmfrnyjcuehq.supabase.co',
          'a-real-looking-anon-key',
        ),
        isFalse,
      );
    });

    test('rejects an unparseable URL', () {
      expect(
        SupabaseConfig.isValidConfig(
          'not a url at all',
          'a-real-looking-anon-key',
        ),
        isFalse,
      );
    });

    test('rejects a URL with no host', () {
      expect(
        SupabaseConfig.isValidConfig('https://', 'a-real-looking-anon-key'),
        isFalse,
      );
    });
  });
}
