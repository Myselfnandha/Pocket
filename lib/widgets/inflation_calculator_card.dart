import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late int _pastYear;
  double _inflationRate = 6.0; // 6%

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _pastYear = (currentYear - 2).clamp(currentYear - 10, currentYear);
  }

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
    final now = DateTime.now();
    final currentYear = now.year;

    final parsedAmount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final amount = parsedAmount ?? 0.0;
    final isBaseline = _pastYear == currentYear;

    // Use calendar year intervals so whole years are measured accurately
    final pastDate = DateTime(_pastYear, now.month, now.day);

    final result = InflationService.calculatePurchasingPower(
      pastAmount: amount,
      pastDate: pastDate,
      today: now,
      annualInflationRate: _inflationRate / 100.0,
    );

    final availableYears = List.generate(11, (i) => currentYear - 10 + i);

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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 20, color: AppColors.accentOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inflation & Purchasing Power',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  items: availableYears.reversed.map((y) {
                    return DropdownMenuItem(
                      value: y,
                      child: Text(y == currentYear ? '$y (Now)' : '$y'),
                    );
                  }).toList(),
                  onChanged: (y) {
                    if (y != null) setState(() => _pastYear = y);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Time Horizon Pills (UI Logic)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickPill('This Year ($currentYear)', currentYear, isDark),
                const SizedBox(width: 6),
                _buildQuickPill('1 yr ago (${currentYear - 1})', currentYear - 1, isDark),
                const SizedBox(width: 6),
                _buildQuickPill('2 yrs ago (${currentYear - 2})', currentYear - 2, isDark),
                const SizedBox(width: 6),
                _buildQuickPill('5 yrs ago (${currentYear - 5})', currentYear - 5, isDark),
                const SizedBox(width: 6),
                _buildQuickPill('10 yrs ago (${currentYear - 10})', currentYear - 10, isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Comparison Hero Result Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBaseline
                    ? (isDark
                        ? [const Color(0xFF14241B), const Color(0xFF161E1A)]
                        : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)])
                    : (isDark
                        ? [const Color(0xFF261C14), const Color(0xFF1A1A1A)]
                        : [const Color(0xFFFFF3E0), const Color(0xFFFAFAFA)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isBaseline
                    ? AppColors.incomeGreen.withValues(alpha: 0.35)
                    : AppColors.accentOrange.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBaseline
                      ? 'Baseline Reference Year ($currentYear):'
                      : '$currency${currencyFormat.format(result.originalAmount)} in $_pastYear is equivalent to:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isBaseline
                      ? '$currency${currencyFormat.format(amount)} Today'
                      : '$currency${currencyFormat.format(result.equivalentAmountToday)} Today',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isBaseline ? AppColors.incomeGreen : AppColors.accentOrange,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isBaseline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.incomeGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🌱 100% Real Value • Present Baseline',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.incomeGreen),
                        ),
                      ),
                      Text(
                        '• Zero compound inflation loss against current purchasing power',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ] else ...[
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
                      Text(
                        '• ${(result.yearDifference).toStringAsFixed(1)} yrs compound effect',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ],
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
            activeColor: isBaseline ? AppColors.incomeGreen : AppColors.accentOrange,
            onChanged: (val) => setState(() => _inflationRate = val),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill(String label, int year, bool isDark) {
    final isSelected = _pastYear == year;
    return InkWell(
      onTap: () => setState(() => _pastYear = year),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentOrange.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF242424) : const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentOrange : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.accentOrange : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
