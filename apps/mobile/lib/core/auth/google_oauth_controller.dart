import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import 'mobile_auth_contract.dart';

enum GoogleOAuthPhase { idle, launchingBrowser, awaitingCallback, failed }

class GoogleOAuthState {
  const GoogleOAuthState({required this.phase, this.message});

  const GoogleOAuthState.idle() : this(phase: GoogleOAuthPhase.idle);

  final GoogleOAuthPhase phase;
  final String? message;

  bool get isBusy =>
      phase == GoogleOAuthPhase.launchingBrowser ||
      phase == GoogleOAuthPhase.awaitingCallback;
}

enum MobileAuthSignal {
  initialSession,
  signedIn,
  userUpdated,
  signedOut,
  other,
}

/// Narrow boundary around Supabase Auth so the launch-to-session state machine
/// is deterministic and can be regression-tested without a hosted backend.
abstract interface class GoogleOAuthGateway {
  Stream<MobileAuthSignal> get authSignals;

  String? get currentSessionUserId;

  String? get currentUserId;

  Future<bool> launchGoogle();
}

class SupabaseGoogleOAuthGateway implements GoogleOAuthGateway {
  SupabaseGoogleOAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<MobileAuthSignal> get authSignals =>
      _client.auth.onAuthStateChange.map(
        (state) => switch (state.event) {
          AuthChangeEvent.initialSession => MobileAuthSignal.initialSession,
          AuthChangeEvent.signedIn => MobileAuthSignal.signedIn,
          AuthChangeEvent.userUpdated => MobileAuthSignal.userUpdated,
          AuthChangeEvent.signedOut => MobileAuthSignal.signedOut,
          _ => MobileAuthSignal.other,
        },
      );

  @override
  String? get currentSessionUserId => _client.auth.currentSession?.user.id;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<bool> launchGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: MobileAuthContract.callbackUrl,
      scopes: 'openid email profile',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }
}

final googleOAuthGatewayProvider = Provider<GoogleOAuthGateway>((ref) {
  return SupabaseGoogleOAuthGateway(ref.watch(supabaseClientProvider));
});

final googleOAuthTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(minutes: 3);
});

class GoogleOAuthController extends Notifier<GoogleOAuthState> {
  StreamSubscription<MobileAuthSignal>? _subscription;
  Timer? _timeoutTimer;
  int _attempt = 0;
  bool _disposed = false;

  late GoogleOAuthGateway _gateway;
  late Duration _timeout;

  @override
  GoogleOAuthState build() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    _disposed = false;
    _gateway = ref.watch(googleOAuthGatewayProvider);
    _timeout = ref.watch(googleOAuthTimeoutProvider);
    _subscription = _gateway.authSignals.listen(_handleAuthSignal);
    ref.onDispose(_dispose);
    return const GoogleOAuthState.idle();
  }

  Future<void> start() async {
    if (state.isBusy) return;

    _timeoutTimer?.cancel();
    final attempt = ++_attempt;
    state = const GoogleOAuthState(phase: GoogleOAuthPhase.launchingBrowser);

    try {
      final launched = await _gateway.launchGoogle();
      if (_disposed || attempt != _attempt) return;

      if (_hasConsistentSession) {
        _complete();
        return;
      }

      if (!launched) {
        state = const GoogleOAuthState(
          phase: GoogleOAuthPhase.failed,
          message: 'Google sign-in could not open. Try again.',
        );
        return;
      }

      state = const GoogleOAuthState(phase: GoogleOAuthPhase.awaitingCallback);
      _timeoutTimer = Timer(_timeout, () {
        if (_disposed || attempt != _attempt) return;
        state = const GoogleOAuthState(
          phase: GoogleOAuthPhase.failed,
          message: 'Google sign-in timed out. Return here and try again.',
        );
      });
    } on AuthException {
      if (_disposed || attempt != _attempt) return;
      state = const GoogleOAuthState(
        phase: GoogleOAuthPhase.failed,
        message: 'Google sign-in was not completed. Try again.',
      );
    } catch (_) {
      if (_disposed || attempt != _attempt) return;
      state = const GoogleOAuthState(
        phase: GoogleOAuthPhase.failed,
        message: 'Could not open Google sign-in. Check your connection.',
      );
    }
  }

  void cancel() {
    if (!state.isBusy) return;
    _attempt++;
    _timeoutTimer?.cancel();
    state = const GoogleOAuthState.idle();
  }

  void clearError() {
    if (state.phase == GoogleOAuthPhase.failed) {
      state = const GoogleOAuthState.idle();
    }
  }

  bool get _hasConsistentSession => MobileAuthContract.hasConsistentSession(
    sessionUserId: _gateway.currentSessionUserId,
    currentUserId: _gateway.currentUserId,
  );

  void _handleAuthSignal(MobileAuthSignal signal) {
    if (_disposed || !state.isBusy) return;
    if (signal != MobileAuthSignal.initialSession &&
        signal != MobileAuthSignal.signedIn &&
        signal != MobileAuthSignal.userUpdated) {
      return;
    }

    if (_hasConsistentSession) {
      _complete();
      return;
    }

    if (_gateway.currentSessionUserId != null ||
        _gateway.currentUserId != null) {
      _attempt++;
      _timeoutTimer?.cancel();
      state = const GoogleOAuthState(
        phase: GoogleOAuthPhase.failed,
        message: 'LOOP could not verify this session. Please sign in again.',
      );
    }
  }

  void _complete() {
    _attempt++;
    _timeoutTimer?.cancel();
    state = const GoogleOAuthState.idle();
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _attempt++;
    _timeoutTimer?.cancel();
    _subscription?.cancel();
  }
}

final googleOAuthControllerProvider =
    NotifierProvider<GoogleOAuthController, GoogleOAuthState>(
      GoogleOAuthController.new,
    );
