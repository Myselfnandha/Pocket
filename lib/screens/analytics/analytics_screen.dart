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
  int? _touchedBarIndex;

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

    // Determine min and max month boundary based on transactions
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

    // Calculate daily spending points for the bar chart
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final Map<int, double> dailySpending = {};
    for (int i = 1; i <= daysInMonth; i++) {
      dailySpending[i] = 0;
    }
    for (final tx in monthTxs) {
      if (tx.type == TransactionType.expense) {
        dailySpending[tx.date.day] = (dailySpending[tx.date.day] ?? 0) + tx.amount;
      }
    }

    final monthExpenses = monthTxs.where((tx) => tx.type == TransactionType.expense).toList();
    final currencyFormat = NumberFormat('#,##0.00');

    final maxSpend = dailySpending.values.fold(0.0, (m, v) => v > m ? v : m);
    final maxY = maxSpend > 0 ? (maxSpend * 1.25) : 1000.0;

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
            // Month Selector Bar (Constrained to transaction dates)
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

            // Top Summary Grid: Income | Expenses | Net Savings (Enlarged to fill grid)
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

            // Daily Cash Flow Bar Chart (Replacement for trend line chart)
            Text(
              'Daily Cash Flow Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 230,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: monthExpenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📊', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            'No expenses logged this month',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final day = group.x + 1;
                              final val = rod.toY;
                              return BarTooltipItem(
                                'Day $day\n${settings.currencySymbol}${currencyFormat.format(val)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                          touchCallback: (event, response) {
                            if (response?.spot != null) {
                              setState(() {
                                _touchedBarIndex = response!.spot!.touchedBarGroupIndex;
                              });
                            } else {
                              setState(() => _touchedBarIndex = null);
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              getTitlesWidget: (val, meta) {
                                if (val == 0 || val == maxY) return const SizedBox.shrink();
                                return Text(
                                  NumberFormat.compact().format(val),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (daysInMonth / 6).floorToDouble(),
                              getTitlesWidget: (val, meta) {
                                final day = val.toInt() + 1;
                                if (day <= 0 || day > daysInMonth) return const SizedBox.shrink();
                                return Text(
                                  'D$day',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder).withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(daysInMonth, (index) {
                          final spend = dailySpending[index + 1] ?? 0;
                          final isPeak = maxSpend > 0 && spend == maxSpend;
                          final isTouched = _touchedBarIndex == index;

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: spend,
                                color: isPeak
                                    ? AppColors.accentOrange
                                    : (isTouched
                                        ? AppColors.primaryGreen
                                        : AppColors.primaryGreenLight),
                                width: daysInMonth > 28 ? 6 : 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Category Breakdown (Donut Chart)
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

            // Export Financial Data Row (Fixed currency & clear icons)
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
