import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_model.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'core_providers.dart';

class SettingsNotifier extends StateNotifier<UserSettingsModel> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.getSettings());

  Future<void> updateSettings(UserSettingsModel newSettings) async {
    state = newSettings;
    await _storage.saveSettings(newSettings);

    // Update scheduled daily reminder if changed
    await NotificationService().scheduleDailyReminder(
      hour: newSettings.dailyReminderHour,
      minute: newSettings.dailyReminderMinute,
      enabled: newSettings.dailyReminderEnabled,
    );
  }

  Future<void> setCurrency(String symbol, String code) async {
    await updateSettings(
      state.copyWith(currencySymbol: symbol, currencyCode: code),
    );
  }

  Future<void> setUserName(String name) async {
    await updateSettings(state.copyWith(userName: name));
  }

  Future<void> completeOnboarding() async {
    await updateSettings(state.copyWith(isOnboarded: true));
  }

  Future<void> toggleCategoryTags(bool value) async {
    await updateSettings(state.copyWith(showCategoryTags: value));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettingsModel>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

// --- Theme Mode & Data Calculation ---

final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.themeMode == AppThemeMode.autoTime) {
    final hour = DateTime.now().hour;
    if (hour >= 18 || hour < 6) {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }

  switch (settings.manualThemeStyle) {
    case ManualThemeStyle.light:
      return ThemeMode.light;
    case ManualThemeStyle.dark:
    case ManualThemeStyle.pureBlack:
      return ThemeMode.dark;
  }
});

final activePaletteProvider = Provider<AppThemePalette>((ref) {
  final settings = ref.watch(settingsProvider);
  return AppThemePalette.fromSettings(
    preset: settings.themePreset,
    customColorValue: settings.customAccentColorValue,
  );
});

final activeAccentColorProvider = Provider<Color>((ref) {
  final palette = ref.watch(activePaletteProvider);
  return palette.primary;
});

final activeDarkThemeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsProvider);
  final palette = ref.watch(activePaletteProvider);
  final isAmoled = settings.isPureBlackEnabled ||
      (settings.themeMode == AppThemeMode.manual &&
          settings.manualThemeStyle == ManualThemeStyle.pureBlack);
  return AppTheme.getDarkTheme(isPureBlack: isAmoled, palette: palette);
});

final activeLightThemeProvider = Provider<ThemeData>((ref) {
  final palette = ref.watch(activePaletteProvider);
  return AppTheme.getLightTheme(palette: palette);
});
