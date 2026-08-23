import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/auth/google_oauth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'keeps OAuth busy until a consistent signed-in session arrives',
    () async {
      final gateway = _FakeGoogleOAuthGateway();
      final container = _containerFor(gateway);
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
      });

      final controller = container.read(googleOAuthControllerProvider.notifier);
      final launch = controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(googleOAuthControllerProvider).phase,
        GoogleOAuthPhase.launchingBrowser,
      );

      gateway.completeLaunch(true);
      await launch;
      expect(
        container.read(googleOAuthControllerProvider).phase,
        GoogleOAuthPhase.awaitingCallback,
      );

      gateway
        ..sessionUserId = 'user-1'
        ..userId = 'user-1'
        ..emit(MobileAuthSignal.signedIn);

      expect(
        container.read(googleOAuthControllerProvider).phase,
        GoogleOAuthPhase.idle,
      );
    },
  );

  test(
    'prevents duplicate browser launches while an attempt is active',
    () async {
      final gateway = _FakeGoogleOAuthGateway();
      final container = _containerFor(gateway);
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
      });

      final controller = container.read(googleOAuthControllerProvider.notifier);
      final first = controller.start();
      await controller.start();

      expect(gateway.launchCalls, 1);
      gateway.completeLaunch(true);
      await first;
    },
  );

  test(
    'reports a browser launch failure without waiting for callback',
    () async {
      final gateway = _FakeGoogleOAuthGateway();
      final container = _containerFor(gateway);
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
      });

      final controller = container.read(googleOAuthControllerProvider.notifier);
      final launch = controller.start();
      gateway.completeLaunch(false);
      await launch;

      final state = container.read(googleOAuthControllerProvider);
      expect(state.phase, GoogleOAuthPhase.failed);
      expect(state.message, contains('could not open'));
    },
  );

  test('times out a launched flow that never produces a session', () async {
    final gateway = _FakeGoogleOAuthGateway();
    final container = _containerFor(
      gateway,
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(() async {
      container.dispose();
      await gateway.dispose();
    });

    final controller = container.read(googleOAuthControllerProvider.notifier);
    final launch = controller.start();
    gateway.completeLaunch(true);
    await launch;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(googleOAuthControllerProvider);
    expect(state.phase, GoogleOAuthPhase.failed);
    expect(state.message, contains('timed out'));
  });

  test('fails closed when session and current user ids disagree', () async {
    final gateway = _FakeGoogleOAuthGateway();
    final container = _containerFor(gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.dispose();
    });

    final controller = container.read(googleOAuthControllerProvider.notifier);
    final launch = controller.start();
    gateway.completeLaunch(true);
    await launch;

    gateway
      ..sessionUserId = 'session-user'
      ..userId = 'different-user'
      ..emit(MobileAuthSignal.signedIn);

    final state = container.read(googleOAuthControllerProvider);
    expect(state.phase, GoogleOAuthPhase.failed);
    expect(state.message, contains('could not verify'));
  });

  test('cancel invalidates a late browser-launch result', () async {
    final gateway = _FakeGoogleOAuthGateway();
    final container = _containerFor(gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.dispose();
    });

    final controller = container.read(googleOAuthControllerProvider.notifier);
    final launch = controller.start();
    controller.cancel();
    gateway.completeLaunch(true);
    await launch;

    expect(
      container.read(googleOAuthControllerProvider).phase,
      GoogleOAuthPhase.idle,
    );
  });

  test(
    'handles a Google cancellation stream error without an unhandled error',
    () async {
      final gateway = _FakeGoogleOAuthGateway();
      final container = _containerFor(gateway);
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
      });

      final controller = container.read(googleOAuthControllerProvider.notifier);
      final launch = controller.start();
      gateway.completeLaunch(true);
      await launch;

      gateway.emitError(
        const AuthException('cancelled', code: 'access_denied'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(googleOAuthControllerProvider);
      expect(state.phase, GoogleOAuthPhase.failed);
      expect(state.message, contains('canceled'));
    },
  );

  test('consumes unrelated auth stream errors while OAuth is idle', () async {
    final gateway = _FakeGoogleOAuthGateway();
    final container = _containerFor(gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.dispose();
    });

    container.read(googleOAuthControllerProvider);
    gateway.emitError(const AuthException('offline'));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(googleOAuthControllerProvider).phase,
      GoogleOAuthPhase.idle,
    );
  });
}

ProviderContainer _containerFor(
  _FakeGoogleOAuthGateway gateway, {
  Duration timeout = const Duration(minutes: 3),
}) {
  return ProviderContainer(
    overrides: [
      googleOAuthGatewayProvider.overrideWithValue(gateway),
      googleOAuthTimeoutProvider.overrideWithValue(timeout),
    ],
  );
}

class _FakeGoogleOAuthGateway implements GoogleOAuthGateway {
  final _signals = StreamController<MobileAuthSignal>.broadcast(sync: true);
  final _launch = Completer<bool>();

  int launchCalls = 0;
  String? sessionUserId;
  String? userId;

  @override
  Stream<MobileAuthSignal> get authSignals => _signals.stream;

  @override
  String? get currentSessionUserId => sessionUserId;

  @override
  String? get currentUserId => userId;

  @override
  Future<bool> launchGoogle() {
    launchCalls++;
    return _launch.future;
  }

  void completeLaunch(bool launched) => _launch.complete(launched);

  void emit(MobileAuthSignal signal) => _signals.add(signal);

  void emitError(Object error) => _signals.addError(error, StackTrace.current);

  Future<void> dispose() => _signals.close();
}
