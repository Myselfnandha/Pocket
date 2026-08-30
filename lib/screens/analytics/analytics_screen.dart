import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/budget_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isMonthBarVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      if (direction == ScrollDirection.reverse && _isMonthBarVisible) {
        setState(() => _isMonthBarVisible = false);
      } else if (direction == ScrollDirection.forward && !_isMonthBarVisible) {
        setState(() => _isMonthBarVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _previousMonth(DateTime minDate) {
    final prev = DateTime(_currentMonth.year, _currentMonth.month - 1);
    if (!prev.isBefore(DateTime(minDate.year, minDate.month))) {
      setState(() => _currentMonth = prev);
    }
  }

  void _nextMonth(DateTime maxDate) {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (!next.isAfter(DateTime(maxDate.year, maxDate.month))) {
      setState(() => _currentMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTxs = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final categoryBudgets = ref.watch(categoryBudgetsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    DateTime minDate = DateTime(now.year, now.month);
    DateTime maxDate = DateTime(now.year, now.month);

    for (final tx in allTxs) {
      if (tx.date.isBefore(minDate)) {
        minDate = DateTime(tx.date.year, tx.date.month);
      }
      if (tx.date.isAfter(maxDate)) {
        maxDate = DateTime(tx.date.year, tx.date.month);
      }
    }

    final canGoBack = _currentMonth.isAfter(DateTime(minDate.year, minDate.month));
    final canGoForward = _currentMonth.isBefore(DateTime(maxDate.year, maxDate.month));

    // Filter transactions for this month
    final monthTxs = allTxs.where((tx) {
      return tx.date.year == _currentMonth.year &&
          tx.date.month == _currentMonth.month;
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    for (final tx in monthTxs) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }

    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100).clamp(0.0, 100.0) : 0.0;
    final monthExpenses = monthTxs.where((tx) => tx.type == TransactionType.expense).toList();
    final currencyFormat = NumberFormat('#,##0.00');

    // Calculate category spending map for this month
    final Map<String, double> catExpenseTotals = {};
    final Map<String, int> catExpenseCounts = {};
    for (final tx in monthExpenses) {
      catExpenseTotals[tx.categoryId] = (catExpenseTotals[tx.categoryId] ?? 0) + tx.amount;
      catExpenseCounts[tx.categoryId] = (catExpenseCounts[tx.categoryId] ?? 0) + 1;
    }

    String? topCatId;
    double topCatSpend = 0;
    for (final entry in catExpenseTotals.entries) {
      if (entry.value > topCatSpend) {
        topCatSpend = entry.value;
        topCatId = entry.key;
      }
    }

    final topCategory = categories.firstWhere(
      (c) => c.id == topCatId,
      orElse: () => const CategoryModel(id: '', name: 'None', icon: '🏷️', colorValue: 0xFF2E7D32),
    );

    // Calculate Day-of-Week spending distribution (Mon = 1, Sun = 7)
    final Map<int, double> dayOfWeekSpending = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final tx in monthExpenses) {
      final weekday = tx.date.weekday;
      dayOfWeekSpending[weekday] = (dayOfWeekSpending[weekday] ?? 0) + tx.amount;
    }

    int peakWeekday = 1;
    double peakWeekdaySpend = 0;
    for (final entry in dayOfWeekSpending.entries) {
      if (entry.value > peakWeekdaySpend) {
        peakWeekdaySpend = entry.value;
        peakWeekday = entry.key;
      }
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final peakDayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][peakWeekday - 1];

    final maxDaySpend = dayOfWeekSpending.values.fold(0.0, (m, v) => v > m ? v : m);
    final maxBarY = maxDaySpend > 0 ? (maxDaySpend * 1.25) : 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(monthTxs, categories),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreenLight,
          labelColor: AppColors.primaryGreenLight,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          tabs: const [
            Tab(text: 'Insights & Charts', icon: Icon(Icons.insights_rounded, size: 18)),
            Tab(text: 'Category Budgets', icon: Icon(Icons.track_changes_rounded, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month Selector Bar (Only on Insights tab & hides on scroll)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: (_tabController.index == 0 && _isMonthBarVisible)
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            color: canGoBack ? AppColors.primaryGreenLight : Colors.grey.withValues(alpha: 0.4),
                            onPressed: canGoBack ? () => _previousMonth(minDate) : null,
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(_currentMonth),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            color: canGoForward ? AppColors.primaryGreenLight : Colors.grey.withValues(alpha: 0.4),
                            onPressed: canGoForward ? () => _nextMonth(maxDate) : null,
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Tab Bar Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Insights & Charts
                _buildInsightsTab(
                  context,
                  scrollController: _scrollController,
                  isDark: isDark,
                  settings: settings,
                  currencyFormat: currencyFormat,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netSavings: netSavings,
                  savingsRate: savingsRate,
                  monthExpenses: monthExpenses,
                  catExpenseTotals: catExpenseTotals,
                  categories: categories,
                  categoryBudgets: categoryBudgets,
                  topCategory: topCategory,
                  topCatSpend: topCatSpend,
                  peakDayName: peakDayName,
                  peakWeekday: peakWeekday,
                  peakWeekdaySpend: peakWeekdaySpend,
                  dayOfWeekSpending: dayOfWeekSpending,
                  maxBarY: maxBarY,
                  dayNames: dayNames,
                  monthTxs: monthTxs,
                ),

                // TAB 2: Category Budgets
                _buildBudgetsTab(
                  context,
                  ref,
                  isDark: isDark,
                  settings: settings,
                  categories: categories,
                  categoryBudgets: categoryBudgets,
                  catExpenseTotals: catExpenseTotals,
                  currencyFormat: currencyFormat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Insights & Charts ---
  Widget _buildInsightsTab(
    BuildContext context, {
    required ScrollController scrollController,
    required bool isDark,
    required dynamic settings,
    required NumberFormat currencyFormat,
    required double totalIncome,
    required double totalExpense,
    required double netSavings,
    required double savingsRate,
    required List<TransactionModel> monthExpenses,
    required Map<String, double> catExpenseTotals,
    required List<CategoryModel> categories,
    required List<CategoryBudgetModel> categoryBudgets,
    required CategoryModel topCategory,
    required double topCatSpend,
    required String peakDayName,
    required int peakWeekday,
    required double peakWeekdaySpend,
    required Map<int, double> dayOfWeekSpending,
    required double maxBarY,
    required List<String> dayNames,
    required List<TransactionModel> monthTxs,
  }) {
    final now = DateTime.now();
    final totalBudgetLimit = categoryBudgets.fold(0.0, (s, b) => s + b.monthlyLimit);
    final remainingBudget = (totalBudgetLimit > 0)
        ? (totalBudgetLimit - totalExpense)
        : (totalIncome - totalExpense);

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Summary Grid: Income | Expenses | Net Savings
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryBox(
                        label: 'Income',
                        amount: '+${settings.currencySymbol}${currencyFormat.format(totalIncome)}',
                        color: AppColors.incomeGreen,
                        icon: Icons.call_received_rounded,
                      ),
                    ),
                    Container(width: 1, height: 40, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    Expanded(
                      child: _SummaryBox(
                        label: 'Expense',
                        amount: '-${settings.currencySymbol}${currencyFormat.format(totalExpense)}',
                        color: AppColors.expenseRed,
                        icon: Icons.call_made_rounded,
                      ),
                    ),
                    Container(width: 1, height: 40, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    Expanded(
                      child: _SummaryBox(
                        label: 'Net Savings',
                        amount: '${netSavings >= 0 ? '+' : '-'}${settings.currencySymbol}${currencyFormat.format(netSavings.abs())}',
                        color: netSavings >= 0 ? AppColors.infoBlue : AppColors.expenseRed,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Savings Rate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      '${savingsRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: savingsRate >= 20 ? AppColors.incomeGreen : AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (savingsRate / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(savingsRate >= 20 ? AppColors.incomeGreen : AppColors.accentOrange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1.5 Quick Stats Row: Daily Average & Monthly Savings
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    final daysElapsed = _currentMonth.year == now.year && _currentMonth.month == now.month
                        ? now.day
                        : DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
                    final totalDays = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
                    final avgDaily = daysElapsed > 0 ? totalExpense / daysElapsed : 0.0;
                    final projectedTotal = avgDaily * totalDays;
                    _showDailyAvgSpendDialog(
                      context,
                      totalExpense: totalExpense,
                      daysElapsed: daysElapsed,
                      totalDays: totalDays,
                      avgDaily: avgDaily,
                      projectedTotal: projectedTotal,
                      currencySymbol: settings.currencySymbol,
                      isCurrentMonth: _currentMonth.year == now.year && _currentMonth.month == now.month,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.accentOrange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Daily Avg Spend',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 11,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${settings.currencySymbol}${currencyFormat.format(_currentMonth.year == now.year && _currentMonth.month == now.month ? (now.day > 0 ? totalExpense / now.day : 0.0) : (DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month) > 0 ? totalExpense / DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month) : 0.0))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: (remainingBudget >= 0 ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: remainingBudget >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              totalBudgetLimit > 0 ? 'Budget Left' : 'Safe to Spend',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${remainingBudget >= 0 ? '+' : '-'}${settings.currencySymbol}${currencyFormat.format(remainingBudget.abs())}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: remainingBudget >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Spending Breakdown by Category (Pie Chart)
          Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: monthExpenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No expenses recorded for this month',
                        style: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _buildPieSections(catExpenseTotals, categories, totalExpense),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      const SizedBox(height: 12),
                      ..._buildCategoryLegend(catExpenseTotals, categories, totalExpense, settings.currencySymbol, currencyFormat, isDark),
                    ],
                  ),
          ),
          const SizedBox(height: 18),

          // 3. Day of Week Pattern (Bar Chart)
          Text(
            'Spending Pattern by Weekday',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Peak Spending Day',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    Text(
                      '$peakDayName (${settings.currencySymbol}${currencyFormat.format(peakWeekdaySpend)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      maxY: maxBarY,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= dayNames.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  dayNames[idx],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: List.generate(7, (idx) {
                        final spend = dayOfWeekSpending[idx + 1] ?? 0.0;
                        final isPeak = (idx + 1) == peakWeekday && spend > 0;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: spend,
                              color: isPeak ? AppColors.accentOrange : AppColors.primaryGreenLight,
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Export Actions
          Row(
            children: [
              Expanded(
                child: _ExportActionCard(
                  icon: Icons.table_chart_outlined,
                  iconColor: AppColors.incomeGreen,
                  title: 'Export CSV',
                  subtitle: 'Spreadsheet format',
                  onTap: () => _exportCsv(monthTxs, categories),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ExportActionCard(
                  icon: Icons.picture_as_pdf_outlined,
                  iconColor: AppColors.expenseRed,
                  title: 'Export PDF',
                  subtitle: 'Printable statement',
                  onTap: () => _exportPdf(monthTxs, categories, settings, totalIncome, totalExpense, netSavings),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- TAB 2: Category Budgets ---
  Widget _buildBudgetsTab(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    required dynamic settings,
    required List<CategoryModel> categories,
    required List<CategoryBudgetModel> categoryBudgets,
    required Map<String, double> catExpenseTotals,
    required NumberFormat currencyFormat,
  }) {
    final totalBudget = categoryBudgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
    double totalSpentInBudgetedCats = 0;
    for (final b in categoryBudgets) {
      totalSpentInBudgetedCats += (catExpenseTotals[b.categoryId] ?? 0.0);
    }
    final overallProgress = totalBudget > 0 ? (totalSpentInBudgetedCats / totalBudget).clamp(0.0, 1.0) : 0.0;
    final isOverallExceeded = totalSpentInBudgetedCats > totalBudget && totalBudget > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Overall Monthly Budget Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MONTHLY BUDGET CAP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                    Text(
                      '${(overallProgress * 100).toStringAsFixed(1)}% Spent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isOverallExceeded
                            ? AppColors.expenseRed
                            : (overallProgress >= 0.75 ? AppColors.accentOrange : AppColors.incomeGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${settings.currencySymbol}${currencyFormat.format(totalSpentInBudgetedCats)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'Cap: ${settings.currencySymbol}${currencyFormat.format(totalBudget)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    minHeight: 8,
                    backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverallExceeded
                          ? AppColors.expenseRed
                          : (overallProgress >= 0.75 ? AppColors.accentOrange : AppColors.primaryGreenLight),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isOverallExceeded
                      ? '⚠️ Total budget exceeded by ${settings.currencySymbol}${currencyFormat.format(totalSpentInBudgetedCats - totalBudget)}'
                      : 'Safe buffer: ${settings.currencySymbol}${currencyFormat.format(totalBudget - totalSpentInBudgetedCats)} remaining for ${DateFormat('MMMM').format(_currentMonth)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOverallExceeded ? AppColors.expenseRed : AppColors.incomeGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Section Header & Add Budget Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Spending Limits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primaryGreenLight,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('+ Add Budget', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _showSetBudgetDialog(context, ref, categories, null, settings.currencySymbol),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Category Budgets List
          if (categoryBudgets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.track_changes_rounded, size: 36, color: AppColors.primaryGreenLight),
                  ),
                  const SizedBox(height: 12),
                  const Text('No Category Budgets Set', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'Set monthly spending limits for categories like Food, Shopping, or Bills to monitor safe daily spending and avoid overspending.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Set Your First Budget', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => _showSetBudgetDialog(context, ref, categories, null, settings.currencySymbol),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryBudgets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final budget = categoryBudgets[index];
                final cat = categories.firstWhere(
                  (c) => c.id == budget.categoryId,
                  orElse: () => const CategoryModel(id: '', name: 'Unknown Category', icon: '🏷️', colorValue: 0xFF4CAF50),
                );
                final spent = catExpenseTotals[budget.categoryId] ?? 0.0;
                final progress = budget.calculateProgress(spent);
                final safeDaily = budget.calculateDailySafeSpend(spent, referenceDate: _currentMonth);
                final isExceeded = spent > budget.monthlyLimit;
                final isNearLimit = spent >= (budget.monthlyLimit * 0.75) && !isExceeded;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExceeded
                          ? AppColors.expenseRed.withValues(alpha: 0.6)
                          : (isNearLimit
                              ? AppColors.accentOrange.withValues(alpha: 0.6)
                              : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
                      width: isExceeded || isNearLimit ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    if (budget.isRolloverEnabled) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.infoBlue.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('ROLLOVER', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.infoBlue)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${settings.currencySymbol}${currencyFormat.format(spent)} of ${settings.currencySymbol}${currencyFormat.format(budget.monthlyLimit)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isExceeded)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.expenseRed.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('OVER BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.expenseRed)),
                            )
                          else
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isNearLimit ? AppColors.accentOrange : AppColors.incomeGreen,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isExceeded
                                ? AppColors.expenseRed
                                : (isNearLimit ? AppColors.accentOrange : AppColors.incomeGreen),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Bottom Row: Safe Daily Spending & Quick Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isExceeded ? Icons.error_outline_rounded : Icons.shield_outlined,
                                size: 13,
                                color: isExceeded ? AppColors.expenseRed : AppColors.incomeGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExceeded
                                    ? 'Over by ${settings.currencySymbol}${currencyFormat.format(spent - budget.monthlyLimit)}'
                                    : 'Safe: ${settings.currencySymbol}${currencyFormat.format(safeDaily)}/day left',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isExceeded ? AppColors.expenseRed : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                visualDensity: VisualDensity.compact,
                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                onPressed: () => _showSetBudgetDialog(context, ref, categories, budget, settings.currencySymbol),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                visualDensity: VisualDensity.compact,
                                color: AppColors.expenseRed,
                                onPressed: () => ref.read(categoryBudgetsProvider.notifier).deleteBudget(budget.id),
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
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  void _showSetBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    List<CategoryModel> categories,
    CategoryBudgetModel? existingBudget,
    String currencySymbol,
  ) {
    final expenseCategories = categories.where((c) => c.type == TransactionType.expense).toList();
    String selectedCatId = existingBudget?.categoryId ?? (expenseCategories.isNotEmpty ? expenseCategories.first.id : 'food');
    final amountCtrl = TextEditingController(text: existingBudget != null ? existingBudget.monthlyLimit.toStringAsFixed(0) : '');
    bool isRollover = existingBudget?.isRolloverEnabled ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existingBudget == null ? 'Set Category Budget' : 'Edit Category Budget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCatId,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: expenseCategories.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCatId = val);
                  },
                ),
                const SizedBox(height: 14),

                Text('Monthly Budget Limit ($currencySymbol)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currencySymbol ',
                    hintText: 'e.g. 5000',
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Carry-over Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Roll unspent budget to next month', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Switch(
                      value: isRollover,
                      activeThumbColor: AppColors.primaryGreenLight,
                      onChanged: (v) => setDialogState(() => isRollover = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final limit = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (limit <= 0) return;

                ref.read(categoryBudgetsProvider.notifier).setBudget(
                      categoryId: selectedCatId,
                      monthlyLimit: limit,
                      isRolloverEnabled: isRollover,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Save Budget'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper chart builders ---

  List<PieChartSectionData> _buildPieSections(
    Map<String, double> catTotals,
    List<CategoryModel> categories,
    double totalExpense,
  ) {
    if (totalExpense <= 0) return [];
    final colors = [
      AppColors.primaryGreenLight,
      AppColors.accentOrange,
      AppColors.infoBlue,
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
      const Color(0xFF26A69A),
      const Color(0xFFEC407A),
      const Color(0xFF78909C),
    ];

    int colorIdx = 0;
    return catTotals.entries.map((e) {
      final percentage = (e.value / totalExpense) * 100;
      final color = colors[colorIdx % colors.length];
      colorIdx++;

      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 45,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black),
      );
    }).toList();
  }

  List<Widget> _buildCategoryLegend(
    Map<String, double> catTotals,
    List<CategoryModel> categories,
    double totalExpense,
    String currencySymbol,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final colors = [
      AppColors.primaryGreenLight,
      AppColors.accentOrange,
      AppColors.infoBlue,
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
      const Color(0xFF26A69A),
      const Color(0xFFEC407A),
      const Color(0xFF78909C),
    ];

    int colorIdx = 0;
    return catTotals.entries.map((e) {
      final cat = categories.firstWhere(
        (c) => c.id == e.key,
        orElse: () => const CategoryModel(id: '', name: 'Other', icon: '🏷️', colorValue: 0xFF2E7D32),
      );
      final percentage = totalExpense > 0 ? (e.value / totalExpense) * 100 : 0.0;
      final color = colors[colorIdx % colors.length];
      colorIdx++;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(cat.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
            Text(
              '$currencySymbol${currencyFormat.format(e.value)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _exportCsv(List<TransactionModel> txs, List<CategoryModel> categories) async {
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export for this month'), duration: Duration(seconds: 4)),
      );
      return;
    }

    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Title', 'Type', 'Amount', 'Category', 'Wallet', 'Note']
    ];

    for (final tx in txs) {
      final cat = categories.firstWhere(
        (c) => c.id == tx.categoryId,
        orElse: () => const CategoryModel(id: '', name: 'Other', icon: '', colorValue: 0),
      );
      rows.add([
        tx.id,
        DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
        tx.title,
        tx.type.name,
        tx.amount,
        cat.name,
        tx.walletId,
        tx.note ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Pocket_Ledger_${DateFormat('yyyy_MM').format(_currentMonth)}.csv';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(csvData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Pocket Financial Ledger - ${DateFormat('MMMM yyyy').format(_currentMonth)}',
    );
  }

  Future<void> _exportPdf(
    List<TransactionModel> txs,
    List<CategoryModel> categories,
    dynamic settings,
    double totalIncome,
    double totalExpense,
    double netSavings,
  ) async {
    final pdf = pw.Document();
    final monthStr = DateFormat('MMMM yyyy').format(_currentMonth);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Pocket Financial Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(monthStr, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('Income', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('+${settings.currencySymbol}${totalIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
                pw.Column(children: [
                  pw.Text('Expenses', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('-${settings.currencySymbol}${totalExpense.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                ]),
                pw.Column(children: [
                  pw.Text('Net Savings', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('${settings.currencySymbol}${netSavings.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Title', 'Category', 'Wallet', 'Amount'],
            data: txs.map((tx) {
              final cat = categories.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => const CategoryModel(id: '', name: 'Other', icon: '', colorValue: 0),
              );
              return [
                DateFormat('dd MMM').format(tx.date),
                tx.title,
                cat.name,
                tx.walletId.toUpperCase(),
                '${tx.type == TransactionType.income ? '+' : '-'}${settings.currencySymbol}${tx.amount.toStringAsFixed(2)}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
            cellHeight: 24,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Pocket_Report_${DateFormat('yyyy_MM').format(_currentMonth)}.pdf');
  }

  void _showDailyAvgSpendDialog(
    BuildContext context, {
    required double totalExpense,
    required int daysElapsed,
    required int totalDays,
    required double avgDaily,
    required double projectedTotal,
    required String currencySymbol,
    required bool isCurrentMonth,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat('#,##0.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: AppColors.accentOrange, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Daily Avg Spend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrentMonth
                  ? 'Your daily spending speed for the current month so far:'
                  : 'Your daily spending rate across the entire month:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Month Expenses:'),
                      Text(
                        '$currencySymbol${currencyFormat.format(totalExpense)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.expenseRed),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isCurrentMonth ? 'Days Elapsed:' : 'Total Days:'),
                      Text(
                        '$daysElapsed days',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Burning Rate:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '$currencySymbol${currencyFormat.format(avgDaily)} / day',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accentOrange, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isCurrentMonth) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_graph_rounded, size: 16, color: AppColors.infoBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Projected Month-End Spend: $currencySymbol${currencyFormat.format(projectedTotal)}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.infoBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreenLight)),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _SummaryBox({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _ExportActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
