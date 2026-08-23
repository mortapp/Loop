import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/auth/google_oauth_controller.dart';
import 'package:loop_mobile/core/theme/app_theme.dart';
import 'package:loop_mobile/features/auth/auth_screen.dart';

void main() {
  testWidgets('sign in accepts an existing non-empty short password', (
    tester,
  ) async {
    final submissions = <EmailPasswordSubmission>[];
    await _pumpAuth(
      tester,
      submitter: (submission) async {
        submissions.add(submission);
        return true;
      },
    );

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'oldpass',
    );
    await _tapAuthSubmit(tester);
    await tester.pump();

    expect(submissions, hasLength(1));
    expect(submissions.single.isSignIn, isTrue);
    expect(submissions.single.password, 'oldpass');
  });

  testWidgets('sign in fails closed when no session can be verified', (
    tester,
  ) async {
    await _pumpAuth(tester, submitter: (_) async => false);
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'oldpass',
    );

    await _tapAuthSubmit(tester);
    await tester.pump();

    expect(
      find.text('LOOP could not verify your session. Try signing in again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('auth-notice')), findsNothing);
  });

  testWidgets('sign up requires a matching password confirmation', (
    tester,
  ) async {
    final submissions = <EmailPasswordSubmission>[];
    await _pumpAuth(
      tester,
      submitter: (submission) async {
        submissions.add(submission);
        return false;
      },
    );
    await _toggleAuthMode(tester);

    expect(
      find.byKey(const Key('auth-confirm-password-field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'strong-password',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password-field')),
      'different-password',
    );
    await _tapAuthSubmit(tester);
    await tester.pump();

    expect(find.text("Passwords don't match"), findsOneWidget);
    expect(submissions, isEmpty);

    await tester.enterText(
      find.byKey(const Key('auth-confirm-password-field')),
      'strong-password',
    );
    await _tapAuthSubmit(tester);
    await tester.pump();

    expect(submissions, hasLength(1));
    expect(submissions.single.isSignIn, isFalse);
    expect(
      find.text('Check your email to finish creating your account.'),
      findsOneWidget,
    );
  });

  testWidgets('mode changes clear passwords but preserve the email address', (
    tester,
  ) async {
    await _pumpAuth(tester);
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'private-password',
    );

    await _toggleAuthMode(tester);

    expect(
      _field(tester, 'auth-email-field').controller!.text,
      'person@example.com',
    );
    expect(_field(tester, 'auth-password-field').controller!.text, isEmpty);
  });

  testWidgets('password visibility and keyboard focus flow are usable', (
    tester,
  ) async {
    await _pumpAuth(tester);
    expect(_editable(tester, 'auth-password-field').obscureText, isTrue);

    await tester.tap(find.byKey(const Key('auth-password-visibility')));
    await tester.pump();
    expect(_editable(tester, 'auth-password-field').obscureText, isFalse);

    await tester.tap(find.byKey(const Key('auth-email-field')));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(_editable(tester, 'auth-password-field').focusNode.hasFocus, isTrue);

    await _toggleAuthMode(tester);
    await tester.tap(find.byKey(const Key('auth-password-field')));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      _editable(tester, 'auth-confirm-password-field').focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('email submission clears a stale Google launch error', (
    tester,
  ) async {
    await _pumpAuth(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('auth-google-error')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'oldpass',
    );
    await _tapAuthSubmit(tester);
    await tester.pump();

    expect(find.byKey(const Key('auth-google-error')), findsNothing);
  });

  testWidgets('small Samsung layout remains scrollable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuth(tester, textScale: 2);
    await _toggleAuthMode(tester);

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TextFormField _field(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(find.byKey(Key(key)));
}

EditableText _editable(WidgetTester tester, String fieldKey) {
  return tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(Key(fieldKey)),
      matching: find.byType(EditableText),
    ),
  );
}

Future<void> _pumpAuth(
  WidgetTester tester, {
  EmailPasswordSubmitter? submitter,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        googleOAuthGatewayProvider.overrideWithValue(
          const _UnavailableOAuthGateway(),
        ),
        emailPasswordSubmitterProvider.overrideWithValue(
          submitter ?? (_) async => true,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AuthScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapAuthSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('auth-submit'));
  await tester.ensureVisible(submit);
  await tester.pump();
  await tester.tap(submit);
}

Future<void> _toggleAuthMode(WidgetTester tester) async {
  final toggle = find.byKey(const Key('auth-mode-toggle'));
  await tester.ensureVisible(toggle);
  await tester.pump();
  await tester.tap(toggle);
  await tester.pump();
}

class _UnavailableOAuthGateway implements GoogleOAuthGateway {
  const _UnavailableOAuthGateway();

  @override
  Stream<MobileAuthSignal> get authSignals => const Stream.empty();

  @override
  String? get currentSessionUserId => null;

  @override
  String? get currentUserId => null;

  @override
  Future<bool> launchGoogle() async => false;
}
