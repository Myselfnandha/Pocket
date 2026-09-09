import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/recurring_model.dart';
import '../../models/settings_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blurred_dialog_utils.dart';
import '../../widgets/top_capsule_toast.dart';

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
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: palette.primary),
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
                                ? palette.primary
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
                                ? palette.primary
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
                ? _buildRulesListView(rules, categories, wallets, settings, currencyFormat, isDark, palette)
                : _buildCalendarView(rules, categories, wallets, settings, currencyFormat, isDark, palette),
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
    dynamic palette,
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
                  color: (palette.primary as Color).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.autorenew_rounded, size: 48, color: palette.primary),
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
      separatorBuilder: (context, index) => const SizedBox(height: 10),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(rule.templatePreset.defaultIcon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.title,
                          style: TextStyle(
                            fontSize: 15,
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
                                color: rule.isPaused ? AppColors.accentOrange : (palette.primary as Color),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: rule.isActive && !rule.isPaused ? AppColors.expenseRed : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262626) : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262626) : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(wallet.icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              wallet.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: const Size(0, 28),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                          ),
                          icon: const Icon(Icons.skip_next_rounded, size: 14),
                          label: const Text('Skip', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            ref.read(recurringRulesProvider.notifier).skipNextCycle(rule.id);
                            TopCapsuleToast.show(
                              context,
                              title: 'Cycle Skipped',
                              subtitle: 'Skipped 1 cycle for ${rule.title}',
                              accentColor: palette.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          rule.isPaused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                          size: 20,
                          color: rule.isPaused ? (palette.primary as Color) : AppColors.accentOrange,
                        ),
                        onPressed: () => ref.read(recurringRulesProvider.notifier).togglePauseRule(rule.id),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expenseRed),
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
    dynamic palette,
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
                    Icon(Icons.calendar_month_rounded, size: 18, color: palette.primary),
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
              childAspectRatio: 1.05,
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
                        ? (palette.primary as Color).withValues(alpha: 0.25)
                        : (hasBills
                            ? AppColors.accentOrange.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkSurfaceVariant : Colors.white)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? (palette.primary as Color)
                          : (isToday
                              ? AppColors.accentOrange
                              : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
                      width: isSelected || isToday ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 4,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday || hasBills ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected
                                ? (palette.primary as Color)
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                      ),
                      if (hasBills)
                        Positioned(
                          bottom: 3,
                          child: Text(
                            billsByDay[dayNum]!.first.templatePreset.defaultIcon,
                            style: const TextStyle(fontSize: 11),
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

    final freqScrollCtrl = FixedExtentScrollController(initialItem: RecurringFrequency.values.indexOf(frequency));
    final dayScrollCtrl = FixedExtentScrollController(initialItem: dueDay - 1);

    showBlurredDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 660),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.autorenew_rounded, size: 20, color: palette.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Recurring Rule',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                'Automate recurring bills and subscriptions',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Template Preset Horizontal Strip
                          Text(
                            'Quick Templates',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: RecurringTemplatePreset.values.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final preset = RecurringTemplatePreset.values[idx];
                                final isSelected = selectedPreset == preset;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
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
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? palette.primary.withValues(alpha: 0.2)
                                          : (isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF2F2F2)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? palette.primary
                                            : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                        width: isSelected ? 1.4 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(preset.defaultIcon, style: const TextStyle(fontSize: 13)),
                                        const SizedBox(width: 6),
                                        Text(
                                          preset.displayName.split(' (').first,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected
                                                ? palette.primary
                                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Title Input
                          TextField(
                            controller: titleCtrl,
                            decoration: InputDecoration(
                              labelText: 'Title / Description',
                              hintText: 'e.g. Netflix, Rent, Spotify',
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Amount Input
                          TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Recurring Amount',
                              prefixText: '$currencySymbol ',
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // iOS Wheel Drum Pickers for Frequency & Due Day
                          Text(
                            'Schedule Frequency & Due Day',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 105,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Frequency Wheel
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: freqScrollCtrl,
                                    itemExtent: 32,
                                    diameterRatio: 1.2,
                                    selectionOverlay: Container(
                                      decoration: BoxDecoration(
                                        color: palette.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.symmetric(
                                          horizontal: BorderSide(color: palette.primary.withValues(alpha: 0.35)),
                                        ),
                                      ),
                                    ),
                                    onSelectedItemChanged: (idx) {
                                      HapticFeedback.selectionClick();
                                      setModalState(() {
                                        frequency = RecurringFrequency.values[idx];
                                      });
                                    },
                                    children: RecurringFrequency.values.map((f) {
                                      final isCur = f == frequency;
                                      return Center(
                                        child: Text(
                                          f.name.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isCur ? FontWeight.w800 : FontWeight.w500,
                                            color: isCur
                                                ? palette.primary
                                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 60,
                                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                ),
                                // Due Day Wheel
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: dayScrollCtrl,
                                    itemExtent: 32,
                                    diameterRatio: 1.2,
                                    selectionOverlay: Container(
                                      decoration: BoxDecoration(
                                        color: palette.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.symmetric(
                                          horizontal: BorderSide(color: palette.primary.withValues(alpha: 0.35)),
                                        ),
                                      ),
                                    ),
                                    onSelectedItemChanged: (idx) {
                                      HapticFeedback.selectionClick();
                                      setModalState(() {
                                        dueDay = idx + 1;
                                      });
                                    },
                                    children: List.generate(31, (index) => index + 1).map((day) {
                                      final isCur = day == dueDay;
                                      return Center(
                                        child: Text(
                                          'Day $day',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isCur ? FontWeight.w800 : FontWeight.w500,
                                            color: isCur
                                                ? palette.primary
                                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Category & Wallet Dropdowns
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('cat_$selectedCategory'),
                                  initialValue: selectedCategory,
                                  isDense: true,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  ),
                                  items: categories.map((c) {
                                    return DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}', overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('wal_$selectedWallet'),
                                  initialValue: selectedWallet,
                                  isDense: true,
                                  decoration: InputDecoration(
                                    labelText: 'Account',
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  ),
                                  items: wallets.map((w) {
                                    return DropdownMenuItem(value: w.id, child: Text('${w.icon} ${w.name}', overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (val) => setModalState(() => selectedWallet = val ?? selectedWallet),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),

                  // Stacked Action Buttons: Cancel directly ABOVE Create Recurring Rule
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Full-width glowing Create Recurring Rule Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
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
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (context.mounted) {
                                TopCapsuleToast.show(
                                  context,
                                  title: 'Recurring Rule Created',
                                  subtitle: '$title • $currencySymbol$amount',
                                  accentColor: palette.primary,
                                );
                              }
                            },
                            child: const Text('Create Recurring Rule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                        ),
                      ],
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
