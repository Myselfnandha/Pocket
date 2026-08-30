import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class FinancialHealthGauge extends ConsumerWidget {
  const FinancialHealthGauge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(financialHealthReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scoreColor = report.totalScore >= 800
        ? const Color(0xFF00E676)
        : report.totalScore >= 650
            ? AppColors.primaryGreenLight
            : report.totalScore >= 500
                ? AppColors.accentOrange
                : AppColors.expenseRed;

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
                  Icon(Icons.speed_rounded, size: 20, color: AppColors.primaryGreenLight),
                  SizedBox(width: 8),
                  Text(
                    'Financial Health Score',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'GRADE ${report.grade}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: scoreColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Central Radial Speedometer Gauge
          Center(
            child: SizedBox(
              width: 200,
              height: 110,
              child: CustomPaint(
                painter: _HealthGaugePainter(
                  score: report.totalScore,
                  scoreColor: scoreColor,
                  isDark: isDark,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${report.totalScore}',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        report.statusTitle.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: Text(
              report.statusSummary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4 Pillar Breakdown Cards
          Column(
            children: report.pillars.map((pillar) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191919) : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF292929) : const Color(0xFFE8E8E8),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pillar.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          '${pillar.score}/${pillar.maxScore} pts (${pillar.status})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pillar.ratio >= 0.7 ? AppColors.incomeGreen : (pillar.ratio >= 0.4 ? AppColors.accentOrange : AppColors.expenseRed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pillar.ratio,
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pillar.ratio >= 0.7 ? AppColors.incomeGreen : (pillar.ratio >= 0.4 ? AppColors.accentOrange : AppColors.expenseRed),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Actionable Tips
          if (report.actionableTips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreenLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primaryGreenLight),
                      SizedBox(width: 6),
                      Text('Actionable Financial Recommendations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryGreenLight)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...report.actionableTips.map((tip) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppColors.primaryGreenLight, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              tip,
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthGaugePainter extends CustomPainter {
  final int score;
  final Color scoreColor;
  final bool isDark;

  _HealthGaugePainter({
    required this.score,
    required this.scoreColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.42;

    // Background track arc
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Active score arc
    final sweepFraction = (score / 1000.0).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: pi,
        endAngle: 2 * pi,
        colors: [
          AppColors.expenseRed,
          AppColors.accentOrange,
          AppColors.primaryGreenLight,
          const Color(0xFF00E676),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * sweepFraction,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthGaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.isDark != isDark;
  }
}
