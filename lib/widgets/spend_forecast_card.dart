import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../services/ai_forecasting_service.dart';
import '../theme/app_theme.dart';

class SpendForecastCard extends ConsumerWidget {
  const SpendForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(monthSpendForecastProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = settings.currencySymbol;
    final currencyFormat = NumberFormat('#,##0');

    final bool isSurplus = forecast.projectedMonthEndBalance >= 0;

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
                  Icon(Icons.auto_graph_rounded, size: 20, color: AppColors.infoBlue),
                  SizedBox(width: 8),
                  Text(
                    'On-Device Spend Forecast',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AI PREDICTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.infoBlue, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Predicts month-end expense & balance from burn rate + scheduled recurring bills with 90% confidence bands.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Primary Forecast Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Projected Expense',
                  value: '$currency${currencyFormat.format(forecast.projectedMonthEndExpense)}',
                  sub: 'Range: $currency${currencyFormat.format(forecast.lowerExpenseBound)} - $currency${currencyFormat.format(forecast.upperExpenseBound)}',
                  color: AppColors.expenseRed,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Projected Month-End',
                  value: '$currency${currencyFormat.format(forecast.projectedMonthEndBalance)}',
                  sub: isSurplus ? 'Estimated positive cashflow' : 'Estimated deficit',
                  color: isSurplus ? AppColors.incomeGreen : AppColors.expenseRed,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Daily Burn Rate',
                  value: '$currency${currencyFormat.format(forecast.currentDailyBurnRate)}/day',
                  sub: '${forecast.daysRemainingInMonth} days remaining',
                  color: AppColors.accentOrange,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Upcoming Bills',
                  value: '$currency${currencyFormat.format(forecast.upcomingRecurringBillsTotal)}',
                  sub: 'Scheduled in recurring rules',
                  color: AppColors.infoBlue,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Forecast Trajectory Shaded Chart
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _ForecastTrajectoryPainter(
                trajectory: forecast.trajectory,
                daysElapsed: forecast.daysElapsed,
                totalDays: forecast.totalDaysInMonth,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Chart Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(color: AppColors.primaryGreenLight, label: 'Actual Spend'),
              const SizedBox(width: 16),
              _buildLegendDot(color: AppColors.infoBlue, label: 'AI Forecast'),
              const SizedBox(width: 16),
              _buildLegendDot(color: AppColors.infoBlue.withValues(alpha: 0.3), label: 'Confidence Band'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191919) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _ForecastTrajectoryPainter extends CustomPainter {
  final List<DailySpendPoint> trajectory;
  final int daysElapsed;
  final int totalDays;
  final bool isDark;

  _ForecastTrajectoryPainter({
    required this.trajectory,
    required this.daysElapsed,
    required this.totalDays,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trajectory.isEmpty) return;

    final double maxVal = trajectory.map((p) => p.upperConfidenceBound).reduce(max);
    if (maxVal <= 0) return;

    final double stepX = size.width / max(1, totalDays - 1);

    // 1. Draw Confidence Envelope Band (Upper -> Lower)
    final confidencePath = Path();
    final List<Offset> upperPoints = [];
    final List<Offset> lowerPoints = [];

    for (int i = 0; i < trajectory.length; i++) {
      final p = trajectory[i];
      final x = i * stepX;
      final yUpper = size.height - (p.upperConfidenceBound / maxVal * (size.height * 0.85));
      final yLower = size.height - (p.lowerConfidenceBound / maxVal * (size.height * 0.85));
      upperPoints.add(Offset(x, yUpper));
      lowerPoints.add(Offset(x, yLower));
    }

    if (upperPoints.isNotEmpty) {
      confidencePath.moveTo(upperPoints.first.dx, upperPoints.first.dy);
      for (final pt in upperPoints) {
        confidencePath.lineTo(pt.dx, pt.dy);
      }
      for (final pt in lowerPoints.reversed) {
        confidencePath.lineTo(pt.dx, pt.dy);
      }
      confidencePath.close();

      final bandPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.infoBlue.withValues(alpha: isDark ? 0.18 : 0.12);
      canvas.drawPath(confidencePath, bandPaint);
    }

    // 2. Draw Actual Spend Line (Day 1 -> daysElapsed)
    final actualPath = Path();
    bool actualStarted = false;
    for (int i = 0; i < min(daysElapsed, trajectory.length); i++) {
      final p = trajectory[i];
      final x = i * stepX;
      final y = size.height - (p.actualSpent / maxVal * (size.height * 0.85));
      if (!actualStarted) {
        actualPath.moveTo(x, y);
        actualStarted = true;
      } else {
        actualPath.lineTo(x, y);
      }
    }

    final actualPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryGreenLight;
    canvas.drawPath(actualPath, actualPaint);

    // 3. Draw Forecasted Dotted Line (daysElapsed -> totalDays)
    final forecastPath = Path();
    bool forecastStarted = false;
    for (int i = max(0, daysElapsed - 1); i < trajectory.length; i++) {
      final p = trajectory[i];
      final x = i * stepX;
      final y = size.height - (p.forecastedSpent / maxVal * (size.height * 0.85));
      if (!forecastStarted) {
        forecastPath.moveTo(x, y);
        forecastStarted = true;
      } else {
        forecastPath.lineTo(x, y);
      }
    }

    final forecastPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.infoBlue;
    canvas.drawPath(forecastPath, forecastPaint);

    // 4. Current Day Marker Dot
    if (daysElapsed - 1 < trajectory.length) {
      final currentPoint = trajectory[daysElapsed - 1];
      final cx = (daysElapsed - 1) * stepX;
      final cy = size.height - (currentPoint.actualSpent / maxVal * (size.height * 0.85));
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(cx, cy), 4.0, dotPaint);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primaryGreenLight;
      canvas.drawCircle(Offset(cx, cy), 4.0, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastTrajectoryPainter oldDelegate) {
    return oldDelegate.trajectory != trajectory ||
        oldDelegate.daysElapsed != daysElapsed ||
        oldDelegate.isDark != isDark;
  }
}
