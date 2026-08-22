import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to riverpod 3's "legacy" export -- still the right
// tool for a single simple piece of settable state like this.
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personalization → theme: System (default, follows the OS) / Dark /
/// Light — mirrors apps/web's ThemePreference (lib/theme.ts) exactly.
enum ThemePreference { system, dark, light }

ThemeMode themeModeFor(ThemePreference preference) => switch (preference) {
  ThemePreference.system => ThemeMode.system,
  ThemePreference.dark => ThemeMode.dark,
  ThemePreference.light => ThemeMode.light,
};

const _prefsKey = 'loop_theme';

/// The current theme preference. Initial value is overridden in main()
/// after a synchronous SharedPreferences read (same bootstrap-before-
/// runApp pattern as Supabase config) so there's no flash of the wrong
/// theme on cold start.
final themePreferenceProvider = StateProvider<ThemePreference>(
  (ref) => ThemePreference.system,
);

/// Reads the persisted theme preference, if any — called once in main()
/// before runApp.
Future<ThemePreference> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_prefsKey);
  return ThemePreference.values.firstWhere(
    (t) => t.name == stored,
    orElse: () => ThemePreference.system,
  );
}

/// Sets and persists the theme preference.
Future<void> setThemePreference(
  WidgetRef ref,
  ThemePreference preference,
) async {
  ref.read(themePreferenceProvider.notifier).state = preference;
  final prefs = await SharedPreferences.getInstance();
  if (preference == ThemePreference.system) {
    await prefs.remove(_prefsKey);
  } else {
    await prefs.setString(_prefsKey, preference.name);
  }
}
