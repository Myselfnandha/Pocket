import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/recurring_model.dart';
import '../../models/settings_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class RecurringRulesScreen extends ConsumerStatefulWidget {
  const RecurringRulesScreen({super.key});

  @override
  ConsumerState<RecurringRulesScreen> createState() => _RecurringRulesScreenState();
}

class _RecurringRulesScreenState extends ConsumerState<RecurringRulesScreen> {
  int _selectedTab = 0; // 0 = Rules List, 1 = Due Calendar
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedCalendarDay;

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          // Segmented Navigation Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '📋 Rules List (${rules.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 0
                                ? AppColors.primaryGreenLight
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '📅 Due Calendar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 1
                                ? AppColors.primaryGreenLight
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _selectedTab == 0
                ? _buildRulesListView(rules, categories, wallets, settings, currencyFormat, isDark)
                : _buildCalendarView(rules, categories, wallets, settings, currencyFormat, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesListView(
    List<RecurringRuleModel> rules,
    List<CategoryModel> categories,
    List<WalletModel> wallets,
    UserSettingsModel settings,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    if (rules.isEmpty) {
      return Center(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              color: rule.isPaused
                  ? AppColors.accentOrange.withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              width: rule.isPaused ? 1.4 : 1.0,
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
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
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
                            color: rule.isActive && !rule.isPaused
                                ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              '${rule.frequency.name.toUpperCase()} • Due: ${DateFormat('d MMM yyyy').format(rule.nextDueDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: rule.isPaused ? AppColors.accentOrange : AppColors.primaryGreenLight,
                              ),
                            ),
                            if (rule.isPaused)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PAUSED',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentOrange),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${settings.currencySymbol}${currencyFormat.format(rule.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: rule.isActive && !rule.isPaused ? AppColors.expenseRed : Colors.grey,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Skip next due date',
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                          ),
                          icon: const Icon(Icons.skip_next_rounded, size: 16),
                          label: const Text('Skip', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            ref.read(recurringRulesProvider.notifier).skipNextCycle(rule.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Skipped 1 cycle for ${rule.title}'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: rule.isPaused ? 'Resume auto-processing' : 'Pause auto-processing',
                        child: IconButton(
                          icon: Icon(
                            rule.isPaused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                            size: 22,
                            color: rule.isPaused ? AppColors.primaryGreenLight : AppColors.accentOrange,
                          ),
                          onPressed: () => ref.read(recurringRulesProvider.notifier).togglePauseRule(rule.id),
                        ),
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
    );
  }

  Widget _buildCalendarView(
    List<RecurringRuleModel> rules,
    List<CategoryModel> categories,
    List<WalletModel> wallets,
    UserSettingsModel settings,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 = Monday, 7 = Sunday

    // Find rules due in this month
    final Map<int, List<RecurringRuleModel>> billsByDay = {};
    double totalMonthBills = 0.0;

    for (final rule in rules) {
      if (!rule.isActive) continue;
      final due = rule.nextDueDate;
      if (due.year == year && due.month == month) {
        billsByDay.putIfAbsent(due.day, () => []).add(rule);
        totalMonthBills += rule.amount;
      }
    }

    final selectedDayBills = _selectedCalendarDay != null &&
            _selectedCalendarDay!.year == year &&
            _selectedCalendarDay!.month == month
        ? (billsByDay[_selectedCalendarDay!.day] ?? [])
        : <RecurringRuleModel>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
                    _selectedCalendarDay = null;
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_calendarMonth),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
                    _selectedCalendarDay = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Total Month Due Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primaryGreenLight),
                    const SizedBox(width: 8),
                    Text(
                      'Total Bills in ${DateFormat('MMM').format(_calendarMonth)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ],
                ),
                Text(
                  '${settings.currencySymbol}${currencyFormat.format(totalMonthBills)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.expenseRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Weekday Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 38,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks * 7 days
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (firstDayWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox();
              }

              final dayNum = dayOffset + 1;
              final hasBills = billsByDay.containsKey(dayNum);
              final isSelected = _selectedCalendarDay?.day == dayNum &&
                  _selectedCalendarDay?.month == month &&
                  _selectedCalendarDay?.year == year;
              final isToday = DateTime.now().day == dayNum &&
                  DateTime.now().month == month &&
                  DateTime.now().year == year;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCalendarDay = DateTime(year, month, dayNum);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreenLight.withValues(alpha: 0.25)
                        : (hasBills
                            ? AppColors.accentOrange.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkSurfaceVariant : Colors.white)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreenLight
                          : (isToday
                              ? AppColors.accentOrange
                              : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
                      width: isSelected || isToday ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday || hasBills ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primaryGreenLight
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                      if (hasBills)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.expenseRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Selected Day Bills Details
          if (_selectedCalendarDay != null) ...[
            Text(
              'Bills on ${DateFormat('d MMMM yyyy').format(_selectedCalendarDay!)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
            const SizedBox(height: 8),
            if (selectedDayBills.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Text(
                  'No recurring bills due on this day.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              )
            else
              ...selectedDayBills.map((b) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: Row(
                    children: [
                      Text(b.templatePreset.defaultIcon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Text(
                        '${settings.currencySymbol}${currencyFormat.format(b.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.expenseRed),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
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
    RecurringTemplatePreset selectedPreset = RecurringTemplatePreset.custom;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int dueDay = 1;
    RecurringFrequency frequency = RecurringFrequency.monthly;
    String selectedCategory = categories.isNotEmpty ? categories.first.id : 'other';
    String selectedWallet = wallets.isNotEmpty ? wallets.first.id : 'cash';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  Text(
                    'New Recurring Rule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preset Picker
                  Text('Quick Template Preset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RecurringTemplatePreset.values.map((preset) {
                      final isSelected = selectedPreset == preset;
                      return ChoiceChip(
                        avatar: Text(preset.defaultIcon),
                        label: Text(preset.displayName.split(' (').first),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedPreset = preset;
                              if (preset != RecurringTemplatePreset.custom) {
                                titleCtrl.text = preset.displayName.split(' (').first;
                                final match = categories.firstWhere(
                                  (c) => c.id == preset.suggestedCategory,
                                  orElse: () => categories.first,
                                );
                                selectedCategory = match.id;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title / Description',
                      hintText: 'e.g. Netflix Premium 4K',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Recurring Amount',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Frequency & Due Day
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<RecurringFrequency>(
                          initialValue: frequency,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: RecurringFrequency.values.map((f) {
                            return DropdownMenuItem(value: f, child: Text(f.name.toUpperCase()));
                          }).toList(),
                          onChanged: (val) => setModalState(() => frequency = val ?? frequency),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: dueDay,
                          decoration: InputDecoration(
                            labelText: 'Due Day',
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: List.generate(31, (index) => index + 1).map((day) {
                            return DropdownMenuItem(value: day, child: Text('Day $day'));
                          }).toList(),
                          onChanged: (val) => setModalState(() => dueDay = val ?? 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category & Wallet
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: categories.map((c) {
                            return DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}'));
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedWallet,
                          decoration: InputDecoration(
                            labelText: 'Deduct From',
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: wallets.map((w) {
                            return DropdownMenuItem(value: w.id, child: Text('${w.icon} ${w.name}'));
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedWallet = val ?? selectedWallet),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreenLight,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (title.isEmpty || amount <= 0) return;

                        final now = DateTime.now();
                        int nextMonth = now.month;
                        int nextYear = now.year;
                        if (now.day > dueDay) {
                          nextMonth++;
                          if (nextMonth > 12) {
                            nextMonth = 1;
                            nextYear++;
                          }
                        }
                        final daysInTargetMonth = DateUtils.getDaysInMonth(nextYear, nextMonth);
                        final safeDay = dueDay.clamp(1, daysInTargetMonth);
                        final calculatedNextDueDate = DateTime(nextYear, nextMonth, safeDay, 9, 0);

                        final newRule = RecurringRuleModel(
                          id: const Uuid().v4(),
                          title: title,
                          amount: amount,
                          type: TransactionType.expense,
                          categoryId: selectedCategory,
                          walletId: selectedWallet,
                          frequency: frequency,
                          dueDay: dueDay,
                          nextDueDate: calculatedNextDueDate,
                          templatePreset: selectedPreset,
                          note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                          createdAt: now,
                        );

                        await ref.read(recurringRulesProvider.notifier).addRule(newRule);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Create Recurring Rule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
