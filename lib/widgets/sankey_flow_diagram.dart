import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class SankeyNode {
  final String id;
  final String title;
  final String icon;
  final double amount;
  final Color color;
  final bool isLeft; // Left (Inflow) vs Right (Outflow/Savings)

  const SankeyNode({
    required this.id,
    required this.title,
    required this.icon,
    required this.amount,
    required this.color,
    required this.isLeft,
  });
}

class SankeyFlowDiagram extends ConsumerStatefulWidget {
  const SankeyFlowDiagram({super.key});

  @override
  ConsumerState<SankeyFlowDiagram> createState() => _SankeyFlowDiagramState();
}

class _SankeyFlowDiagramState extends ConsumerState<SankeyFlowDiagram> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(monthlyStatsProvider);
    final spendingMap = ref.watch(currentMonthCategorySpendingProvider);
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalIncome = max(1.0, stats.totalIncome);
    final totalExpense = stats.totalExpense;
    final netSavings = max(0.0, stats.totalIncome - stats.totalExpense);

    // Left Node: Total Inflows
    final leftNodes = [
      SankeyNode(
        id: 'inflow_total',
        title: 'Total Inflow',
        icon: '💰',
        amount: totalIncome,
        color: AppColors.incomeGreen,
        isLeft: true,
      ),
    ];

    // Right Nodes: Top Categories + Net Savings
    final List<SankeyNode> rightNodes = [];

    // Sort categories by spending
    final activeCategories = categories
        .where((c) => (spendingMap[c.id] ?? 0.0) > 0)
        .toList()
      ..sort((a, b) => (spendingMap[b.id] ?? 0.0).compareTo(spendingMap[a.id] ?? 0.0));

    final topCategories = activeCategories.take(4).toList();
    final otherCategories = activeCategories.skip(4).toList();
    final otherTotal = otherCategories.fold(0.0, (sum, c) => sum + (spendingMap[c.id] ?? 0.0));

    for (final cat in topCategories) {
      final amt = spendingMap[cat.id] ?? 0.0;
      rightNodes.add(
        SankeyNode(
          id: 'cat_${cat.id}',
          title: cat.name,
          icon: cat.icon,
          amount: amt,
          color: cat.color,
          isLeft: false,
        ),
      );
    }

    if (otherTotal > 0) {
      rightNodes.add(
        SankeyNode(
          id: 'cat_other_bundled',
          title: 'Other Expenses',
          icon: '📦',
          amount: otherTotal,
          color: AppColors.accentOrange,
          isLeft: false,
        ),
      );
    }

    if (netSavings > 0 || totalExpense == 0) {
      rightNodes.add(
        SankeyNode(
          id: 'net_savings',
          title: 'Net Savings',
          icon: '🌱',
          amount: netSavings > 0 ? netSavings : totalIncome,
          color: const Color(0xFF00E676),
          isLeft: false,
        ),
      );
    }

    final effectiveTotalRight = rightNodes.fold(0.0, (sum, n) => sum + n.amount);

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
                  Icon(Icons.alt_route_rounded, size: 20, color: AppColors.primaryGreenLight),
                  SizedBox(width: 8),
                  Text(
                    'Money Flow Topology (Sankey)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'INTERACTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryGreenLight, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Visualizes how your total monthly income distributes directly into category drains & savings retention.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Animated Diagram Canvas
          SizedBox(
            height: 240,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _SankeyPainter(
                    leftNode: leftNodes.first,
                    rightNodes: rightNodes,
                    progress: _animController.value,
                    selectedNodeId: _selectedNodeId,
                    isDark: isDark,
                  ),
                  child: Row(
                    children: [
                      // Left Column
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildNodeCard(
                            leftNodes.first,
                            settings.currencySymbol,
                            totalIncome,
                            isDark,
                          ),
                        ),
                      ),
                      const Expanded(flex: 4, child: SizedBox.expand()),
                      // Right Column
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: rightNodes.map((node) {
                            return _buildNodeCard(
                              node,
                              settings.currencySymbol,
                              effectiveTotalRight,
                              isDark,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(SankeyNode node, String currencySymbol, double totalScale, bool isDark) {
    final isSelected = _selectedNodeId == node.id;
    final pct = totalScale > 0 ? (node.amount / totalScale * 100).toStringAsFixed(0) : '0';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? node.color.withValues(alpha: 0.25)
              : (isDark ? const Color(0xFF181818) : const Color(0xFFF7F7F7)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? node.color : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: node.color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(node.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '$currencySymbol${node.amount.toStringAsFixed(0)} ($pct%)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: node.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SankeyPainter extends CustomPainter {
  final SankeyNode leftNode;
  final List<SankeyNode> rightNodes;
  final double progress;
  final String? selectedNodeId;
  final bool isDark;

  _SankeyPainter({
    required this.leftNode,
    required this.rightNodes,
    required this.progress,
    required this.selectedNodeId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rightNodes.isEmpty) return;

    final double startX = size.width * 0.28;
    final double startY = size.height * 0.5;
    final double endX = size.width * 0.65;

    final totalRightAmount = rightNodes.fold(0.0, (sum, n) => sum + n.amount);
    final count = rightNodes.length;

    for (int i = 0; i < count; i++) {
      final node = rightNodes[i];
      final double endY = count > 1
          ? (size.height * 0.15) + (i * ((size.height * 0.70) / (count - 1)))
          : size.height * 0.5;

      final double fraction = totalRightAmount > 0 ? (node.amount / totalRightAmount) : (1.0 / count);
      final double ribbonWidth = (fraction * 18.0).clamp(3.0, 16.0);

      final isHighlight = selectedNodeId == null || selectedNodeId == node.id || selectedNodeId == leftNode.id;
      final opacity = (isHighlight ? 0.65 : 0.15) * progress;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            leftNode.color.withValues(alpha: opacity),
            node.color.withValues(alpha: opacity),
          ],
        ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)));

      final path = Path();
      path.moveTo(startX, startY);

      // Bezier curve flowing left to right
      final controlX1 = startX + (endX - startX) * 0.45;
      final controlX2 = startX + (endX - startX) * 0.55;

      path.cubicTo(
        controlX1,
        startY,
        controlX2,
        endY,
        endX * progress,
        startY + (endY - startY) * progress,
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.isDark != isDark;
  }
}
