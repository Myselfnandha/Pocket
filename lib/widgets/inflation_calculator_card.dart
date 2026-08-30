import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../services/inflation_service.dart';
import '../theme/app_theme.dart';

class InflationCalculatorCard extends ConsumerStatefulWidget {
  const InflationCalculatorCard({super.key});

  @override
  ConsumerState<InflationCalculatorCard> createState() => _InflationCalculatorCardState();
}

class _InflationCalculatorCardState extends ConsumerState<InflationCalculatorCard> {
  final TextEditingController _amountCtrl = TextEditingController(text: '50000');
  int _pastYear = 2024;
  double _inflationRate = 6.0; // 6%

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = settings.currencySymbol;
    final currencyFormat = NumberFormat('#,##0');

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 50000.0;
    final pastDate = DateTime(_pastYear, 1, 1);

    final result = InflationService.calculatePurchasingPower(
      pastAmount: amount,
      pastDate: pastDate,
      annualInflationRate: _inflationRate / 100.0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              const Row(
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 20, color: AppColors.accentOrange),
                  SizedBox(width: 8),
                  Text(
                    'Inflation & Purchasing Power',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'REAL VALUE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accentOrange, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Compares historical money value to today\'s real purchasing power adjusted for compound CPI inflation.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Amount & Year Input Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Historical Amount',
                    prefixText: '$currency ',
                    filled: true,
                    isDense: true,
                    fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: _pastYear,
                  decoration: InputDecoration(
                    labelText: 'Base Year',
                    filled: true,
                    isDense: true,
                    fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: [2020, 2021, 2022, 2023, 2024, 2025].map((y) {
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }).toList(),
                  onChanged: (y) {
                    if (y != null) setState(() => _pastYear = y);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Comparison Hero Result Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF261C14), const Color(0xFF1A1A1A)]
                    : [const Color(0xFFFFF3E0), const Color(0xFFFAFAFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currency${currencyFormat.format(result.originalAmount)} in $_pastYear is equivalent to:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$currency${currencyFormat.format(result.equivalentAmountToday)} Today',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentOrange,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.expenseRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${result.purchasingPowerLossPercent.toStringAsFixed(1)}% Purchasing Power Loss',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.expenseRed),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${result.yearDifference.toStringAsFixed(1)} years @ ${_inflationRate.toStringAsFixed(1)}% p.a.)',
                      style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Slider for Inflation Rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Assumed Annual Inflation (CPI):', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('${_inflationRate.toStringAsFixed(1)}% / yr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
            ],
          ),
          Slider(
            value: _inflationRate,
            min: 2.0,
            max: 12.0,
            divisions: 20,
            activeColor: AppColors.accentOrange,
            onChanged: (val) => setState(() => _inflationRate = val),
          ),
        ],
      ),
    );
  }
}
