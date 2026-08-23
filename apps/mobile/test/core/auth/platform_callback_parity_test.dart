import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/auth/mobile_auth_contract.dart';

void main() {
  test('Android and iOS register the canonical valid callback scheme', () {
    final callback = Uri.tryParse(MobileAuthContract.callbackUrl);
    expect(callback, isNotNull);
    expect(callback!.scheme, MobileAuthContract.callbackScheme);

    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      androidManifest,
      contains('android:scheme="${MobileAuthContract.callbackScheme}"'),
    );
    expect(
      androidManifest,
      contains('android:host="${MobileAuthContract.callbackHost}"'),
    );
    expect(
      androidManifest,
      contains('android:path="${MobileAuthContract.callbackPath}"'),
    );
    expect(
      androidManifest,
      contains('android:enableOnBackInvokedCallback="true"'),
    );
    expect(androidManifest, contains('android:usesCleartextTraffic="false"'));

    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      iosInfo,
      contains('<string>${MobileAuthContract.callbackScheme}</string>'),
    );
  });
}
