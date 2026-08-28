import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/recurring_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
            tooltip: 'Add Recurring Rule',
            onPressed: () => _showAddRuleDialog(context, ref, categories, wallets, settings.currencySymbol),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.autorenew_rounded, size: 48, color: AppColors.primaryGreenLight),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Recurring Rules Configured',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Automate Rent, EMI, OTT, Electricity, and Subscriptions so Pocket logs them on their due dates.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRuleDialog(context, ref, categories, wallets, settings.currencySymbol),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Recurring Rule'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: rules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final rule = rules[index];
                final cat = categories.firstWhere(
                  (c) => c.id == rule.categoryId,
                  orElse: () => const CategoryModel(id: '', name: 'Other', icon: '📦', colorValue: 0),
                );
                final wallet = wallets.firstWhere(
                  (w) => w.id == rule.walletId,
                  orElse: () => defaultWallets.first,
                );

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: rule.isActive
                          ? (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: rule.isActive
                                  ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(rule.templatePreset.defaultIcon, style: const TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: rule.isActive
                                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${rule.frequency.name.toUpperCase()} • Due: ${DateFormat('d MMM yyyy').format(rule.nextDueDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${settings.currencySymbol}${currencyFormat.format(rule.amount)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: rule.isActive ? AppColors.expenseRed : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(cat.icon, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                              const SizedBox(width: 8),
                              Text(wallet.icon, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                wallet.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Switch(
                                value: rule.isActive,
                                activeThumbColor: AppColors.primaryGreenLight,
                                onChanged: (_) => ref.read(recurringRulesProvider.notifier).toggleRuleActive(rule.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.expenseRed),
                                onPressed: () => ref.read(recurringRulesProvider.notifier).deleteRule(rule.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddRuleDialog(
    BuildContext context,
    WidgetRef ref,
    List<CategoryModel> categories,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    RecurringTemplatePreset selectedPreset = RecurringTemplatePreset.rent;
    final titleCtrl = TextEditingController(text: 'Monthly House Rent');
    final amountCtrl = TextEditingController();
    RecurringFrequency selectedFreq = RecurringFrequency.monthly;
    int selectedDueDay = 1;
    String selectedWalletId = wallets.isNotEmpty ? wallets.first.id : 'bank';
    String selectedCategoryId = 'rent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Recurring Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Preset Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: RecurringTemplatePreset.values.map((preset) {
                    final isSel = selectedPreset == preset;
                    return ChoiceChip(
                      avatar: Text(preset.defaultIcon, style: const TextStyle(fontSize: 13)),
                      label: Text(preset.name.toUpperCase()),
                      selected: isSel,
                      onSelected: (_) {
                        setDialogState(() {
                          selectedPreset = preset;
                          if (preset == RecurringTemplatePreset.rent) {
                            titleCtrl.text = 'House / Flat Rent';
                            selectedCategoryId = 'rent';
                          } else if (preset == RecurringTemplatePreset.emi) {
                            titleCtrl.text = 'Loan EMI Payment';
                            selectedCategoryId = 'bills';
                          } else if (preset == RecurringTemplatePreset.ott) {
                            titleCtrl.text = 'OTT Streaming Subscriptions';
                            selectedCategoryId = 'entertainment';
                          } else if (preset == RecurringTemplatePreset.electricity) {
                            titleCtrl.text = 'Monthly Electricity Bill';
                            selectedCategoryId = 'bills';
                          } else if (preset == RecurringTemplatePreset.phoneBill) {
                            titleCtrl.text = 'Phone & Broadband Bill';
                            selectedCategoryId = 'bills';
                          } else if (preset == RecurringTemplatePreset.insurance) {
                            titleCtrl.text = 'Health / Term Insurance';
                            selectedCategoryId = 'health';
                          } else if (preset == RecurringTemplatePreset.subscription) {
                            titleCtrl.text = 'Software Subscription';
                            selectedCategoryId = 'other';
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Title / Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: titleCtrl),
                const SizedBox(height: 14),
                Text('Recurring Amount ($currencySymbol)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(prefixText: '$currencySymbol ', hintText: '0.00'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Frequency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<RecurringFrequency>(
                            initialValue: selectedFreq,
                            items: RecurringFrequency.values.map((f) {
                              return DropdownMenuItem(value: f, child: Text(f.name.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedFreq = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Due Day of Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDueDay,
                            items: List.generate(28, (i) => i + 1).map((day) {
                              return DropdownMenuItem(value: day, child: Text('Day $day'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedDueDay = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Deduct From Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedWalletId,
                  items: wallets.map((w) {
                    return DropdownMenuItem(value: w.id, child: Text('${w.icon} ${w.name}'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedWalletId = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (title.isEmpty || amount <= 0) return;

                final now = DateTime.now();
                int dueMonth = now.month;
                int dueYear = now.year;
                if (now.day > selectedDueDay) {
                  dueMonth++;
                  if (dueMonth > 12) {
                    dueMonth = 1;
                    dueYear++;
                  }
                }
                final nextDue = DateTime(dueYear, dueMonth, selectedDueDay);

                final newRule = RecurringRuleModel(
                  id: const Uuid().v4(),
                  title: title,
                  amount: amount,
                  type: TransactionType.expense,
                  categoryId: selectedCategoryId,
                  walletId: selectedWalletId,
                  frequency: selectedFreq,
                  dueDay: selectedDueDay,
                  nextDueDate: nextDue,
                  templatePreset: selectedPreset,
                  createdAt: now,
                );

                await ref.read(recurringRulesProvider.notifier).addRule(newRule);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Recurring rule "$title" created ✓'), duration: const Duration(seconds: 4)),
                );
              },
              child: const Text('Save Rule'),
            ),
          ],
        ),
      ),
    );
  }
}
