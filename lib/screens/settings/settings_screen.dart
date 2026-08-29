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
    final recurring = ref.watch(recurringRulesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // 2. Section: Automated Recurring Expenses & Debts
          _buildSectionHeader('FINANCIAL TOOLS & AUTOMATION'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.autorenew_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Recurring Expenses', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${recurring.where((r) => r.isActive).length} active rules (Rent, EMI, OTT...)'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/recurring-rules'),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ListTile(
                leading: const Icon(Icons.handshake_outlined, color: AppColors.infoBlue),
                title: const Text('Lend & Borrow / Debt Tracker', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Track money given or owed to contacts with settlements'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/debts'),
              ),
            ],
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
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppColors.primaryGreenLight),
                title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
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
                subtitle: Text('v1.2.6 • Material 3 Transaction Tracker'),
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

  void _showThemePicker(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    showModalBottomSheet(
      context: context,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
                    onPressed: () => _showAddCategoryDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      leading: Text(cat.icon, style: const TextStyle(fontSize: 22)),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(cat.type == TransactionType.income ? 'Income' : 'Expense'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.expenseRed),
                        onPressed: () => ref.read(categoriesProvider.notifier).deleteCategory(cat.id),
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

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    String icon = '🏷️';
    TransactionType type = TransactionType.expense;

    final icons = ['🍔', '🚗', '🏠', '🛒', '💊', '🎬', '👕', '📱', '⚡', '📚', '✈️', '🎁', '💇', '🔧', '💰', '💼', '📈', '💵', '📦'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Category Name'),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              const Text('Select Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: icons.map((ic) {
                  final isSel = icon == ic;
                  return InkWell(
                    onTap: () => setDialogState(() => icon = ic),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primaryGreenLight.withValues(alpha: 0.3) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ic, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final newCat = CategoryModel(
                    id: const Uuid().v4(),
                    name: name,
                    icon: icon,
                    colorValue: 0xFF4CAF50,
                    type: type,
                  );
                  ref.read(categoriesProvider.notifier).addCategory(newCat);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
