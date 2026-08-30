import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/settings_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // 1. Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    settings.userName.isNotEmpty
                        ? settings.userName[0].toUpperCase()
                        : 'N',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.userName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Currency: ${settings.currencySymbol} (${settings.currencyCode})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editProfileDialog(context, ref, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),



          // 3. Section: Notifications & Reminders
          _buildSectionHeader('NOTIFICATIONS & ALERTS'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.accentOrange),
                title: const Text('Alerts & Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Budget limits (80%/100%), recurring dues, daily reminder'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showNotificationSettingsModal(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Section: Appearance & Theme
          _buildSectionHeader('THEME & APPEARANCE'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final activePalette = ref.watch(activePaletteProvider);
                  return ListTile(
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activePalette.primary,
                        boxShadow: [
                          BoxShadow(
                            color: activePalette.primary.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                      ),
                    ),
                    title: const Text('Theme & Accent Palette', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${activePalette.name} (5 Presets + Custom Color)'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showThemeStudioModal(context, ref, settings),
                  );
                },
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ListTile(
                leading: const Icon(Icons.brightness_medium_rounded, color: AppColors.infoBlue),
                title: const Text('Display Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  settings.themeMode == AppThemeMode.autoTime
                      ? 'Auto Mode (Switches Light/Dark based on time of day)'
                      : (settings.manualThemeStyle == ManualThemeStyle.light
                          ? 'Light Mode'
                          : (settings.manualThemeStyle == ManualThemeStyle.pureBlack || settings.isPureBlackEnabled
                              ? 'Pure Black AMOLED'
                              : 'Dark Mode (Charcoal)')),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemePicker(context, ref, settings),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ListTile(
                leading: const Icon(Icons.widgets_outlined, color: AppColors.primaryGreenLight),
                title: const Text('Home Screen Widget Metric', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_getWidgetMetricTitle(settings.homeScreenWidgetStat)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showWidgetMetricPicker(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Section: Categories & Currency
          _buildSectionHeader('CATEGORIES & CURRENCY'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.category_outlined, color: AppColors.infoBlue),
                title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${categories.length} categories available'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCategoriesManager(context, ref, categories),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              SwitchListTile(
                secondary: const Icon(Icons.label_outline_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Category Tags on Items', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Show or hide category badge tags on transaction rows'),
                value: settings.showCategoryTags,
                activeThumbColor: AppColors.primaryGreenLight,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).toggleCategoryTags(val);
                },
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ListTile(
                leading: const Icon(Icons.currency_exchange_rounded, color: AppColors.accentOrange),
                title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${settings.currencySymbol} - ${settings.currencyCode}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCurrencyPicker(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 6. Section: Data & Account
          _buildSectionHeader('DATA & ACCOUNT'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined, color: AppColors.infoBlue),
                title: const Text('Backup & Database Management', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Full JSON Backup, Restore, CSV Import/Export'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/data-management'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 7. Section: About
          _buildSectionHeader('ABOUT'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: AppColors.primaryGreenLight),
                title: Text('Pocket', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('v1.4.0 • AI & Material 3 Wealth Matrix'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.primaryGreenLight,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(children: children),
    );
  }

  void _showNotificationSettingsModal(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notification Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Budget Warning (80% Reached)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Alert when spending reaches 80% of budget limit'),
                  value: settings.notifyBudgetNearLimit,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(
                          settings.copyWith(notifyBudgetNearLimit: val),
                        );
                    setModalState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Budget Exceeded Alert', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Alert immediately when spending exceeds 100%'),
                  value: settings.notifyBudgetExceeded,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(
                          settings.copyWith(notifyBudgetExceeded: val),
                        );
                    setModalState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Recurring Payment Due Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Notify on or before automated recurring due date'),
                  value: settings.notifyRecurringDue,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(
                          settings.copyWith(notifyRecurringDue: val),
                        );
                    setModalState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Daily Spending Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Evening check-in at ${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}'),
                  value: settings.dailyReminderEnabled,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(
                          settings.copyWith(dailyReminderEnabled: val),
                        );
                    setModalState(() {});
                  },
                ),
                if (settings.dailyReminderEnabled)
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded, color: AppColors.primaryGreenLight),
                    title: const Text('Change Reminder Time'),
                    trailing: Text(
                      '${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreenLight),
                    ),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute),
                      );
                      if (pickedTime != null) {
                        ref.read(settingsProvider.notifier).updateSettings(
                              settings.copyWith(
                                dailyReminderHour: pickedTime.hour,
                                dailyReminderMinute: pickedTime.minute,
                              ),
                            );
                        setModalState(() {});
                      }
                    },
                  ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Monthly Summary Digest', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Monthly report card on savings & spending on the 1st'),
                  value: settings.monthlySummaryEnabled,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(
                          settings.copyWith(monthlySummaryEnabled: val),
                        );
                    setModalState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeStudioModal(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final customColors = [
      0xFF00E676, // Electric Lime
      0xFF00E5FF, // Neon Cyan
      0xFF2979FF, // Electric Blue
      0xFF651FFF, // Deep Indigo
      0xFFD500F9, // Cyber Magenta
      0xFFFF1744, // Crimson Red
      0xFFFF9100, // Amber Flame
      0xFFFFD600, // Radiant Gold
      0xFF1DE9B6, // Seafoam Teal
      0xFFFF4081, // Hot Pink
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final currentSettings = ref.watch(settingsProvider);
          final activePalette = ref.watch(activePaletteProvider);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: activePalette.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.palette_rounded, color: activePalette.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Theme & Accent Studio',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CURATED LUXURY PRESETS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  // 5 Curated Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetCard(
                          title: 'Emerald',
                          color: const Color(0xFF4CAF50),
                          gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          isSelected: currentSettings.themePreset == AppThemePreset.emerald,
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateSettings(
                                  currentSettings.copyWith(
                                    themePreset: AppThemePreset.emerald,
                                    customAccentColorValue: 0xFF4CAF50,
                                  ),
                                );
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildPresetCard(
                          title: 'Cyberpunk',
                          color: const Color(0xFFB388FF),
                          gradient: const [Color(0xFFB388FF), Color(0xFF7C4DFF)],
                          isSelected: currentSettings.themePreset == AppThemePreset.cyberpunk,
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateSettings(
                                  currentSettings.copyWith(
                                    themePreset: AppThemePreset.cyberpunk,
                                    customAccentColorValue: 0xFFB388FF,
                                  ),
                                );
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildPresetCard(
                          title: 'Sapphire',
                          color: const Color(0xFF29B6F6),
                          gradient: const [Color(0xFF29B6F6), Color(0xFF0288D1)],
                          isSelected: currentSettings.themePreset == AppThemePreset.sapphire,
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateSettings(
                                  currentSettings.copyWith(
                                    themePreset: AppThemePreset.sapphire,
                                    customAccentColorValue: 0xFF29B6F6,
                                  ),
                                );
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildPresetCard(
                          title: 'Sunset Gold',
                          color: const Color(0xFFFFB300),
                          gradient: const [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          isSelected: currentSettings.themePreset == AppThemePreset.sunset,
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateSettings(
                                  currentSettings.copyWith(
                                    themePreset: AppThemePreset.sunset,
                                    customAccentColorValue: 0xFFFFB300,
                                  ),
                                );
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildPresetCard(
                          title: 'Rose Quartz',
                          color: const Color(0xFFFF4081),
                          gradient: const [Color(0xFFFF4081), Color(0xFFC2185B)],
                          isSelected: currentSettings.themePreset == AppThemePreset.rose,
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateSettings(
                                  currentSettings.copyWith(
                                    themePreset: AppThemePreset.rose,
                                    customAccentColorValue: 0xFFFF4081,
                                  ),
                                );
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'CUSTOM ACCENT COLOR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  // Custom Swatches
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: customColors.map((colorVal) {
                      final isSelected = currentSettings.themePreset == AppThemePreset.custom &&
                          currentSettings.customAccentColorValue == colorVal;
                      return InkWell(
                        onTap: () {
                          ref.read(settingsProvider.notifier).updateSettings(
                                currentSettings.copyWith(
                                  themePreset: AppThemePreset.custom,
                                  customAccentColorValue: colorVal,
                                ),
                              );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(colorVal),
                            boxShadow: [
                              BoxShadow(
                                color: Color(colorVal).withValues(alpha: 0.4),
                                blurRadius: isSelected ? 10 : 4,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  // Custom Hex Input Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: activePalette.primary,
                      side: BorderSide(color: activePalette.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.colorize_rounded, size: 16),
                    label: const Text('Enter Custom Hex Code (#...)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    onPressed: () => _showHexInputDialog(context, ref, currentSettings),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetCard({
    required String title,
    required Color color,
    required List<Color> gradient,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: gradient),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHexInputDialog(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    final controller = TextEditingController(
      text: '#${settings.customAccentColorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Custom Accent Hex', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Hex Color Code',
            hintText: '#00E676',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final raw = controller.text.replaceAll('#', '').trim();
              if (raw.length == 6) {
                final val = int.tryParse('0xFF$raw');
                if (val != null) {
                  ref.read(settingsProvider.notifier).updateSettings(
                        settings.copyWith(
                          themePreset: AppThemePreset.custom,
                          customAccentColorValue: val,
                        ),
                      );
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply Color'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Theme Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.auto_mode_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Auto Mode (Time-Based)'),
                subtitle: const Text('Automatically switches to Light (6AM-6PM) & Dark (6PM-6AM)'),
                trailing: settings.themeMode == AppThemeMode.autoTime
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).updateSettings(
                        settings.copyWith(themeMode: AppThemeMode.autoTime),
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_rounded, color: AppColors.accentOrange),
                title: const Text('Light Mode'),
                subtitle: const Text('Crisp paper light theme'),
                trailing: (settings.themeMode == AppThemeMode.manual && settings.manualThemeStyle == ManualThemeStyle.light)
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).updateSettings(
                        settings.copyWith(
                          themeMode: AppThemeMode.manual,
                          manualThemeStyle: ManualThemeStyle.light,
                          isPureBlackEnabled: false,
                        ),
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded, color: AppColors.infoBlue),
                title: const Text('Dark Mode (Charcoal)'),
                subtitle: const Text('Standard dark gray interface (#131313)'),
                trailing: (settings.themeMode == AppThemeMode.manual && settings.manualThemeStyle == ManualThemeStyle.dark && !settings.isPureBlackEnabled)
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).updateSettings(
                        settings.copyWith(
                          themeMode: AppThemeMode.manual,
                          manualThemeStyle: ManualThemeStyle.dark,
                          isPureBlackEnabled: false,
                        ),
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Pure Black AMOLED'),
                subtitle: const Text('Deep OLED true black for battery saving'),
                trailing: (settings.themeMode == AppThemeMode.manual && (settings.manualThemeStyle == ManualThemeStyle.pureBlack || settings.isPureBlackEnabled))
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).updateSettings(
                        settings.copyWith(
                          themeMode: AppThemeMode.manual,
                          manualThemeStyle: ManualThemeStyle.pureBlack,
                          isPureBlackEnabled: true,
                        ),
                      );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    final currencies = [
      {'symbol': '₹', 'code': 'INR', 'name': 'Indian Rupee'},
      {'symbol': '\$', 'code': 'USD', 'name': 'US Dollar'},
      {'symbol': '€', 'code': 'EUR', 'name': 'Euro'},
      {'symbol': '£', 'code': 'GBP', 'name': 'British Pound'},
      {'symbol': '¥', 'code': 'JPY', 'name': 'Japanese Yen'},
      {'symbol': 'AED', 'code': 'AED', 'name': 'UAE Dirham'},
      {'symbol': 'C\$', 'code': 'CAD', 'name': 'Canadian Dollar'},
      {'symbol': 'A\$', 'code': 'AUD', 'name': 'Australian Dollar'},
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...currencies.map((c) {
                final isSel = settings.currencyCode == c['code'];
                return ListTile(
                  leading: Text(c['symbol']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  title: Text(c['name']!),
                  subtitle: Text(c['code']!),
                  trailing: isSel
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setCurrency(c['symbol']!, c['code']!);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _editProfileDialog(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    final nameCtrl = TextEditingController(text: settings.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(settingsProvider.notifier).setUserName(newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCategoriesManager(BuildContext context, WidgetRef ref, List<CategoryModel> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Categories (${categories.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => _showCategoryEditDialog(context, ref, null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cat.color.withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: Text(cat.icon, style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: Text(
                        cat.type == TransactionType.income ? '📈 Income' : '📉 Expense',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showCategoryEditDialog(context, ref, cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.expenseRed),
                            onPressed: () => ref.read(categoriesProvider.notifier).deleteCategory(cat.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryEditDialog(BuildContext context, WidgetRef ref, CategoryModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String icon = existing?.icon ?? '🏷️';
    int colorVal = existing?.colorValue ?? 0xFF2E7D32;
    TransactionType type = existing?.type ?? TransactionType.expense;

    final icons = [
      '🍔', '🍕', '☕', '🛒', '🚗', '⛽', '✈️', '🚆', '🏠', '⚡', '💧', '📶',
      '💊', '🏥', '🏋️', '🎬', '🎮', '📚', '👕', '👠', '📱', '💻', '🔧', '🎁',
      '💇', '👶', '🐾', '💰', '💼', '📈', '💵', '💳', '🏦', '🎓', '🏖️', '📦'
    ];

    final colors = [
      0xFF2E7D32, // Emerald
      0xFF00BFA5, // Teal
      0xFF0288D1, // Sky Blue
      0xFF5E35B1, // Purple
      0xFFD81B60, // Pink
      0xFFE53935, // Crimson
      0xFFFB8C00, // Amber
      0xFF8D6E63, // Brown
      0xFF546E7A, // Slate
      0xFF43A047, // Forest Green
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: Text(
              existing == null ? 'New Category' : 'Edit Category',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Pet Care, Subscriptions',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Type Toggle
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Expense'),
                        selected: type == TransactionType.expense,
                        onSelected: (_) => setDialogState(() => type = TransactionType.expense),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: type == TransactionType.income,
                        onSelected: (_) => setDialogState(() => type = TransactionType.income),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  const Text('Category Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.map((c) {
                      final isSel = colorVal == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => colorVal = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSel
                                ? [BoxShadow(color: Color(c).withValues(alpha: 0.6), blurRadius: 6)]
                                : null,
                          ),
                          child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Icon Picker
                  const Text('Select Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: icons.map((ic) {
                      final isSel = icon == ic;
                      return InkWell(
                        onTap: () => setDialogState(() => icon = ic),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel ? Color(colorVal).withValues(alpha: 0.3) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? Color(colorVal) : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                            ),
                          ),
                          child: Text(ic, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenLight,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    if (existing != null) {
                      final updated = existing.copyWith(
                        name: name,
                        icon: icon,
                        colorValue: colorVal,
                        type: type,
                      );
                      ref.read(categoriesProvider.notifier).updateCategory(updated);
                    } else {
                      final newCat = CategoryModel(
                        id: const Uuid().v4(),
                        name: name,
                        icon: icon,
                        colorValue: colorVal,
                        type: type,
                      );
                      ref.read(categoriesProvider.notifier).addCategory(newCat);
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getWidgetMetricTitle(HomeScreenWidgetStat stat) {
    switch (stat) {
      case HomeScreenWidgetStat.balanceAndTodaySpend:
        return 'Total Balance & Today\'s Spend';
      case HomeScreenWidgetStat.netWorth:
        return 'Total Net Worth (Assets - Liabilities)';
      case HomeScreenWidgetStat.monthlySavings:
        return 'Monthly Savings & Savings Rate';
      case HomeScreenWidgetStat.budgetRemaining:
        return 'Monthly Category Budget Remaining';
      case HomeScreenWidgetStat.debtsSummary:
        return 'Total Balance & Accounts Overview';
      case HomeScreenWidgetStat.forecastTrajectory:
        return 'Live Spend Forecast & Sparkline Trajectory';
    }
  }

  void _showWidgetMetricPicker(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Home Screen Widget Metric',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what primary statistic appears on your Android home-screen widget.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...HomeScreenWidgetStat.values.map((stat) {
              final isSel = settings.homeScreenWidgetStat == stat;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isSel
                    ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                    : Colors.transparent,
                leading: Icon(
                  stat == HomeScreenWidgetStat.balanceAndTodaySpend
                      ? Icons.account_balance_wallet_outlined
                      : stat == HomeScreenWidgetStat.netWorth
                          ? Icons.trending_up_rounded
                          : stat == HomeScreenWidgetStat.monthlySavings
                              ? Icons.savings_outlined
                              : stat == HomeScreenWidgetStat.budgetRemaining
                                  ? Icons.pie_chart_outline_rounded
                                  : Icons.receipt_long_outlined,
                  color: isSel ? AppColors.primaryGreenLight : (isDark ? Colors.white70 : Colors.black87),
                ),
                title: Text(
                  _getWidgetMetricTitle(stat),
                  style: TextStyle(
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? AppColors.primaryGreenLight : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                trailing: isSel ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight) : null,
                onTap: () {
                  final updated = settings.copyWith(homeScreenWidgetStat: stat);
                  ref.read(settingsProvider.notifier).updateSettings(updated);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
