import 'dart:io';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
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

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  Future<void> _exportCsv(
    List<TransactionModel> txs,
    List<CategoryModel> categories,
  ) async {
    try {
      final List<List<dynamic>> rows = [
        ['ID', 'Date', 'Title', 'Type', 'Category', 'Wallet', 'Amount', 'Note'],
      ];

      for (final tx in txs) {
        final cat = categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => const CategoryModel(id: '', name: 'Unknown', icon: '', colorValue: 0),
        );
        rows.add([
          tx.id,
          DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
          tx.title,
          tx.type.name,
          cat.name,
          tx.walletId,
          tx.amount,
          tx.note ?? '',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/pocket_transactions_${DateFormat('yyyy_MM').format(_currentMonth)}.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Pocket Transactions Export - ${DateFormat('MMMM yyyy').format(_currentMonth)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf(
    List<TransactionModel> txs,
    List<CategoryModel> categories,
    String currencySymbol,
  ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Pocket - Financial Report (${DateFormat('MMMM yyyy').format(_currentMonth)})',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Title', 'Type', 'Category', 'Amount'],
                  data: txs.map((tx) {
                    final cat = categories.firstWhere(
                      (c) => c.id == tx.categoryId,
                      orElse: () => const CategoryModel(id: '', name: 'Unknown', icon: '', colorValue: 0),
                    );
                    return [
                      DateFormat('dd MMM yyyy').format(tx.date),
                      tx.title,
                      tx.type.name.toUpperCase(),
                      cat.name,
                      '${tx.type == TransactionType.income ? '+' : '-'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/pocket_report_${DateFormat('yyyy_MM').format(_currentMonth)}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Pocket PDF Report - ${DateFormat('MMMM yyyy').format(_currentMonth)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTxs = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    // Calculate daily spending points for the line chart (last 7 days of the month or available days)
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

    final spots = <FlSpot>[];
    for (int day = 1; day <= daysInMonth; day++) {
      spots.add(FlSpot(day.toDouble(), dailySpending[day] ?? 0));
    }

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
            // Month Selector Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: AppColors.primaryGreenLight,
                    onPressed: _previousMonth,
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
                    color: AppColors.primaryGreenLight,
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Monthly Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                          amount: '+${settings.currencySymbol}${totalIncome.toStringAsFixed(0)}',
                          color: AppColors.incomeGreen,
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 48,
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      Expanded(
                        child: _SummaryBox(
                          label: 'Expenses',
                          amount: '-${settings.currencySymbol}${totalExpense.toStringAsFixed(0)}',
                          color: AppColors.expenseRed,
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 48,
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      Expanded(
                        child: _SummaryBox(
                          label: 'Savings',
                          amount: '${settings.currencySymbol}${netSavings.toStringAsFixed(0)}',
                          color: netSavings >= 0 ? AppColors.accentOrange : AppColors.expenseRed,
                          icon: Icons.savings_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: savingsRate / 100,
                      backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreenLight),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Savings Rate',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '${savingsRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreenLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Daily Spending Trend Chart
            Text(
              'Daily Spending Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              height: 220,
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAEAEA),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == maxY) return const SizedBox.shrink();
                          return Text(
                            NumberFormat.compact().format(value),
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
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}d',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.expenseRed,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.expenseRed.withValues(alpha: 0.3),
                            AppColors.expenseRed.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Export Actions Row
            Text(
              'Export Financial Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.table_chart_outlined, color: AppColors.primaryGreenLight),
                    label: const Text('Export CSV'),
                    onPressed: () => _exportCsv(monthTxs, categories),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.accentOrange),
                    label: const Text('Export PDF'),
                    onPressed: () => _exportPdf(monthTxs, categories, settings.currencySymbol),
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
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
