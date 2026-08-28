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

          // 2. Section: Appearance
          _buildSectionHeader('APPEARANCE'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppColors.primaryGreenLight),
                title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_getThemeSubtitle(settings.themePreference)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemePicker(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Section: General
          _buildSectionHeader('GENERAL'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.category_outlined, color: AppColors.infoBlue),
                title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${categories.length} categories configured'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCategoriesManager(context, ref, categories),
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

          // 4. Section: Security
          _buildSectionHeader('SECURITY'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Biometric / PIN Lock', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Require authentication to open Pocket'),
                value: settings.biometricEnabled,
                activeThumbColor: AppColors.primaryGreenLight,
                onChanged: (val) {
                  if (val && settings.pinCode == null) {
                    _showSetPinDialog(context, ref, settings);
                  } else {
                    ref.read(settingsProvider.notifier).updateSettings(
                          settings.copyWith(biometricEnabled: val, pinLockEnabled: val),
                        );
                  }
                },
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ListTile(
                leading: const Icon(Icons.pin_outlined, color: AppColors.accentOrange),
                title: const Text('Change 4-Digit PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(settings.pinCode != null ? 'PIN is configured (••••)' : 'Default PIN: 1234'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSetPinDialog(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Section: About
          _buildSectionHeader('ABOUT'),
          _buildSettingsGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.slideshow_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Replay Onboarding Tour', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View the welcome guide and feature tour'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/onboarding'),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: AppColors.infoBlue),
                title: Text('Pocket', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('v1.0.0 • Material 3 Transaction Tracker'),
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

  Widget _buildSettingsGroup({
    required bool isDark,
    required List<Widget> children,
  }) {
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

  String _getThemeSubtitle(AppThemePreference pref) {
    switch (pref) {
      case AppThemePreference.autoTime:
        return 'Auto (Time-based: Dark at night)';
      case AppThemePreference.darkAmoled:
        return 'Pure Black (AMOLED)';
      case AppThemePreference.light:
        return 'Light Mode';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Select Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _buildThemeOptionTile(
                ctx,
                ref,
                title: 'Auto (Time-based)',
                subtitle: 'Dark mode after 6 PM, Light during day',
                preference: AppThemePreference.autoTime,
                isSelected: settings.themePreference == AppThemePreference.autoTime,
              ),
              _buildThemeOptionTile(
                ctx,
                ref,
                title: 'Pure Black (AMOLED)',
                subtitle: 'True #000000 black background',
                preference: AppThemePreference.darkAmoled,
                isSelected: settings.themePreference == AppThemePreference.darkAmoled,
              ),
              _buildThemeOptionTile(
                ctx,
                ref,
                title: 'Light Mode',
                subtitle: 'Clean bright theme',
                preference: AppThemePreference.light,
                isSelected: settings.themePreference == AppThemePreference.light,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile(
    BuildContext ctx,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required AppThemePreference preference,
    required bool isSelected,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: isSelected ? AppColors.primaryGreenLight : Colors.grey,
      ),
      onTap: () {
        ref.read(settingsProvider.notifier).setThemePreference(preference);
        Navigator.pop(ctx);
      },
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, UserSettingsModel settings) {
    final currencies = [
      {'symbol': '₹', 'code': 'INR', 'name': 'Indian Rupee'},
      {'symbol': '\$', 'code': 'USD', 'name': 'US Dollar'},
      {'symbol': '€', 'code': 'EUR', 'name': 'Euro'},
      {'symbol': '£', 'code': 'GBP', 'name': 'British Pound'},
      {'symbol': '¥', 'code': 'JPY', 'name': 'Japanese Yen'},
      {'symbol': 'A\$', 'code': 'AUD', 'name': 'Australian Dollar'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Select Currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...currencies.map((c) {
                final isSel = settings.currencyCode == c['code'];
                return ListTile(
                  leading: Text(c['symbol']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  title: Text('${c['name']} (${c['code']})'),
                  trailing: isSel ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight) : null,
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
    final controller = TextEditingController(text: settings.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Your Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(settingsProvider.notifier).setUserName(name);
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
        builder: (ctx, scrollController) => Padding(
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
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddCategoryDialog(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: categories.length,
                  separatorBuilder: (ctx, index) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    return ListTile(
                      leading: Text(cat.icon, style: const TextStyle(fontSize: 22)),
                      title: Text(cat.name),
                      subtitle: Text(cat.type == TransactionType.income ? 'Income' : 'Expense'),
                      trailing: cat.isDefault
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.expenseRed),
                              onPressed: () {
                                ref.read(categoriesProvider.notifier).deleteCategory(cat.id);
                              },
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
    final nameController = TextEditingController();
    String icon = '🏷️';
    TransactionType type = TransactionType.expense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Custom Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                  ButtonSegment(value: TransactionType.income, label: Text('Income')),
                ],
                selected: {type},
                onSelectionChanged: (val) => setDialogState(() => type = val.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(categoriesProvider.notifier).addCategory(
                        CategoryModel(
                          id: const Uuid().v4(),
                          name: name,
                          icon: icon,
                          colorValue: 0xFF4CAF50,
                          type: type,
                          isDefault: false,
                        ),
                      );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetPinDialog(
    BuildContext context,
    WidgetRef ref,
    UserSettingsModel settings,
  ) {
    final pinController = TextEditingController(text: settings.pinCode ?? '1234');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set 4-Digit Security PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a 4-digit PIN to secure your transaction and wallet data:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 12,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin.length == 4 && int.tryParse(pin) != null) {
                ref.read(settingsProvider.notifier).updateSettings(
                      settings.copyWith(
                        pinCode: pin,
                        biometricEnabled: true,
                        pinLockEnabled: true,
                      ),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Security PIN saved successfully ✓'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid 4-digit numeric PIN'),
                  ),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }
}
