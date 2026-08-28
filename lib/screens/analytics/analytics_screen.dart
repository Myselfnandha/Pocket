import 'dart:io';
import 'package:flutter/material.dart';
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
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

    // Calculate top spending category
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
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(monthTxs, categories),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector Bar (Constrained)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      fontSize: 16,
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
            const SizedBox(height: 16),

            // Top Summary Grid: Income | Expenses | Net Savings
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
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 52,
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      Expanded(
                        child: _SummaryBox(
                          label: 'Expenses',
                          amount: '-${settings.currencySymbol}${currencyFormat.format(totalExpense)}',
                          color: AppColors.expenseRed,
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 28,
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Savings',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${netSavings >= 0 ? '+' : ''}${settings.currencySymbol}${currencyFormat.format(netSavings)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: netSavings >= 0
                                  ? AppColors.incomeGreen
                                  : AppColors.expenseRed,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: (netSavings >= 0
                                  ? AppColors.incomeGreen
                                  : AppColors.expenseRed)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${savingsRate.toStringAsFixed(1)}% Saved',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: netSavings >= 0
                                ? AppColors.incomeGreen
                                : AppColors.expenseRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top Spending Category & Day-of-Week Breakdown Card
            Text(
              'Most Spending Category & Day-of-Week',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (monthExpenses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text(
                      'No expense records for this month',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log transactions to see category & day-of-week spending patterns',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Top Category Hero Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1B3B22), const Color(0xFF131313)]
                        : [const Color(0xFFE8F5E9), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryGreenLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(topCategory.icon, style: const TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '🔥 #1 TOP CATEGORY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topCategory.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            '${catExpenseCounts[topCatId] ?? 0} transactions • ${(totalExpense > 0 ? (topCatSpend / totalExpense * 100) : 0).toStringAsFixed(1)}% of total expenses',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${settings.currencySymbol}${currencyFormat.format(topCatSpend)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.expenseRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Day of Week Distribution Chart
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
                          'Day-of-Week Cash Outflow',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (peakWeekdaySpend > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Peak: $peakDayName',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          maxY: maxBarY,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final dayName = dayNames[group.x];
                                final val = rod.toY;
                                return BarTooltipItem(
                                  '$dayName\n${settings.currencySymbol}${currencyFormat.format(val)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                                  final isPeak = (idx + 1) == peakWeekday && peakWeekdaySpend > 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      dayNames[idx],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                                        color: isPeak
                                            ? AppColors.accentOrange
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(7, (index) {
                            final spend = dayOfWeekSpending[index + 1] ?? 0;
                            final isPeak = (index + 1) == peakWeekday && spend > 0;

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: spend,
                                  color: isPeak
                                      ? AppColors.accentOrange
                                      : AppColors.primaryGreenLight,
                                  width: 22,
                                  borderRadius: BorderRadius.circular(6),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxBarY,
                                    color: (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0)),
                                  ),
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
            ],
            const SizedBox(height: 24),

            // Category Breakdown Donut Chart
            if (monthExpenses.isNotEmpty) ...[
              Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
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
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 42,
                          sections: _buildPieSections(monthExpenses, categories, totalExpense),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildCategoryLegend(monthExpenses, categories, totalExpense, settings.currencySymbol, currencyFormat, isDark),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Export Financial Data
            Text(
              'Export Financial Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ExportActionCard(
                    icon: Icons.table_chart_rounded,
                    iconColor: AppColors.primaryGreenLight,
                    title: 'Export CSV',
                    subtitle: '${monthTxs.length} items (${settings.currencySymbol})',
                    onTap: () => _exportCsv(monthTxs, categories),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ExportActionCard(
                    icon: Icons.picture_as_pdf_rounded,
                    iconColor: AppColors.expenseRed,
                    title: 'Export PDF',
                    subtitle: 'Summary & Ledger',
                    onTap: () => _exportPdf(monthTxs, categories, settings, totalIncome, totalExpense, netSavings),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    List<TransactionModel> expenses,
    List<CategoryModel> categories,
    double totalExpense,
  ) {
    if (totalExpense <= 0) return [];

    final Map<String, double> catTotals = {};
    for (final tx in expenses) {
      catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amount;
    }

    final palette = [
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFFC107),
    ];

    int colorIdx = 0;
    return catTotals.entries.map((e) {
      final percentage = (e.value / totalExpense * 100);
      final color = palette[colorIdx % palette.length];
      colorIdx++;

      return PieChartSectionData(
        value: e.value,
        color: color,
        title: percentage > 8 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 36,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildCategoryLegend(
    List<TransactionModel> expenses,
    List<CategoryModel> categories,
    double totalExpense,
    String currencySymbol,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final Map<String, double> catTotals = {};
    for (final tx in expenses) {
      catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amount;
    }

    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) {
      final cat = categories.firstWhere(
        (c) => c.id == e.key,
        orElse: () => CategoryModel(id: e.key, name: 'Other', icon: '📦', colorValue: 0xFF9E9E9E),
      );
      final percentage = totalExpense > 0 ? (e.value / totalExpense * 100) : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
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
