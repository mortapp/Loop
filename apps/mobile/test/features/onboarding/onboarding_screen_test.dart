import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/onboarding/onboarding_screen.dart';

void main() {
  const googleIdentity = OnboardingIdentityState(
    userId: 'google-user-id',
    email: 'river.person@example.com',
    suggestedName: 'River Person',
    suggestedUsername: 'riverperson',
    credentialsRequired: true,
  );
  const emailIdentity = OnboardingIdentityState(
    userId: 'email-user-id',
    email: 'email.person@example.com',
    suggestedName: 'Email Person',
    suggestedUsername: 'emailperson',
    credentialsRequired: false,
  );

  testWidgets(
    'credential-required Google state shows both required password fields',
    (tester) async {
      await _pumpOnboarding(tester, identity: googleIdentity);

      expect(
        find.byKey(const Key('onboarding-password-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('onboarding-confirm-password-field')),
        findsOneWidget,
      );
      expect(find.text('REQUIRED'), findsNWidgets(2));
      expect(
        find.text('Required to finish setting up this Google account.'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('onboarding-submit'))).height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('email credential state preserves profile-only onboarding', (
    tester,
  ) async {
    OnboardingSubmission? submitted;
    await _pumpOnboarding(
      tester,
      identity: emailIdentity,
      submitter: (submission) async => submitted = submission,
    );

    expect(find.byKey(const Key('onboarding-password-field')), findsNothing);
    expect(
      find.byKey(const Key('onboarding-confirm-password-field')),
      findsNothing,
    );

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.userId, 'email-user-id');
    expect(submitted!.password, isNull);
  });

  testWidgets('Google onboarding requires and confirms a strong password', (
    tester,
  ) async {
    OnboardingSubmission? submitted;
    await _pumpOnboarding(
      tester,
      identity: googleIdentity,
      submitter: (submission) async => submitted = submission,
    );

    await _tapSubmit(tester);
    await tester.pump();
    expect(find.text('Create a password to continue.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-password-field')),
      'short',
    );
    await _tapSubmit(tester);
    await tester.pump();
    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('onboarding-password-field')),
      'strong-password',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-confirm-password-field')),
      'different-password',
    );
    await _tapSubmit(tester);
    await tester.pump();
    expect(find.text("Passwords don't match."), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-confirm-password-field')),
      'strong-password',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.userId, 'google-user-id');
    expect(submitted!.displayName, 'River Person');
    expect(submitted!.username, 'riverperson');
    expect(submitted!.password, 'strong-password');
  });

  testWidgets('username check failure offers a working retry', (tester) async {
    var attempts = 0;
    await _pumpOnboarding(
      tester,
      identity: googleIdentity,
      usernameChecker: (username) async {
        attempts++;
        if (attempts == 1) throw TimeoutException('offline');
        return true;
      },
    );

    expect(find.text('Could not check availability.'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-username-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-username-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Username available'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('backend details are never rendered in setup errors', (
    tester,
  ) async {
    const privateFailure = 'postgres://private-host internal stack trace';
    await _pumpOnboarding(
      tester,
      identity: googleIdentity,
      submitter: (_) async => throw Exception(privateFailure),
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-password-field')),
      'strong-password',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-confirm-password-field')),
      'strong-password',
    );

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining(privateFailure), findsNothing);
    expect(
      find.text(
        'We could not finish setup. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try setup again'), findsOneWidget);
  });

  testWidgets('late submit completion does not update a disposed screen', (
    tester,
  ) async {
    final completion = Completer<void>();
    await _pumpOnboarding(
      tester,
      identity: googleIdentity,
      submitter: (_) => completion.future,
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-password-field')),
      'strong-password',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-confirm-password-field')),
      'strong-password',
    );
    await _tapSubmit(tester);
    await tester.pump();
    expect(find.text('Finishing setup...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('small Samsung layout supports large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpOnboarding(tester, identity: googleIdentity, textScale: 2);

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('onboarding-scroll-view')),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('onboarding-confirm-password-field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required OnboardingIdentityState identity,
  UsernameAvailabilityChecker? usernameChecker,
  OnboardingSubmitter? submitter,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingIdentityProvider.overrideWithValue(identity),
        onboardingUsernameAvailabilityProvider.overrideWithValue(
          usernameChecker ?? (_) async => true,
        ),
        onboardingSubmitterProvider.overrideWithValue(
          submitter ?? (_) async {},
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('onboarding-submit'));
  await tester.ensureVisible(submit);
  await tester.pump();
  await tester.tap(submit);
}
