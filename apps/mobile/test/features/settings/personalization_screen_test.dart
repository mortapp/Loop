import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/app_theme.dart';
import 'package:loop_mobile/core/theme/theme_preference.dart';
import 'package:loop_mobile/features/settings/personalization_screen.dart';

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = foreground == lighter ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void main() {
  testWidgets('light personalization uses readable theme-aware surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = AppTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePreferenceProvider.overrideWith((ref) => ThemePreference.light),
        ],
        child: MaterialApp(theme: theme, home: const PersonalizationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final option = tester.widget<Container>(
      find.byKey(const ValueKey('theme-option-light')),
    );
    final decoration = option.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surface);

    final optionLabel = tester.widget<Text>(find.text('Light'));
    expect(
      _contrastRatio(optionLabel.style!.color!, decoration.color!),
      greaterThanOrEqualTo(4.5),
    );

    final sectionLabel = tester.widget<Text>(find.text('THEME'));
    expect(
      _contrastRatio(sectionLabel.style!.color!, theme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(tester.takeException(), isNull);
  });
}
