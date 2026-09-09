import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

enum SankeyStage {
  inflow,
  hub,
  outflow,
}

class SankeyNode {
  final String id;
  final String title;
  final String icon;
  final double amount;
  final Color color;
  final SankeyStage stage;

  const SankeyNode({
    required this.id,
    required this.title,
    required this.icon,
    required this.amount,
    required this.color,
    required this.stage,
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
    final wallets = ref.watch(walletsProvider);
    final allTxs = ref.watch(transactionsProvider);
    final settings = ref.watch(settingsProvider);
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final monthTxs = allTxs.where((tx) {
      return tx.date.year == now.year && tx.date.month == now.month;
    }).toList();

    final totalIncome = max(1.0, stats.totalIncome);
    final totalExpense = stats.totalExpense;
    final netSavings = max(0.0, stats.totalIncome - stats.totalExpense);

    // --- STAGE 1 (Left): Inflow Sources ---
    final List<SankeyNode> stage1Nodes = [];
    final incomeTxs = monthTxs.where((tx) => tx.type == TransactionType.income).toList();
    if (incomeTxs.isNotEmpty) {
      final Map<String, double> incomeTotals = {};
      final Map<String, String> incomeIcons = {};
      for (final tx in incomeTxs) {
        final key = tx.title.trim().isNotEmpty ? tx.title.trim() : 'Income';
        incomeTotals[key] = (incomeTotals[key] ?? 0.0) + tx.amount;
        final cat = categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => const CategoryModel(id: '', name: '', icon: '💰', colorValue: 0xFF2E7D32),
        );
        incomeIcons[key] = cat.icon;
      }
      final sortedIncome = incomeTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topIncome = sortedIncome.take(2).toList();
      final otherIncome = sortedIncome.skip(2).fold(0.0, (s, e) => s + e.value);

      for (int i = 0; i < topIncome.length; i++) {
        final entry = topIncome[i];
        stage1Nodes.add(
          SankeyNode(
            id: 'inflow_$i',
            title: entry.key,
            icon: incomeIcons[entry.key] ?? '💰',
            amount: entry.value,
            color: AppColors.incomeGreen,
            stage: SankeyStage.inflow,
          ),
        );
      }
      if (otherIncome > 0) {
        stage1Nodes.add(
          SankeyNode(
            id: 'inflow_other',
            title: 'Other Inflow',
            icon: '💵',
            amount: otherIncome,
            color: const Color(0xFF66BB6A),
            stage: SankeyStage.inflow,
          ),
        );
      }
    }

    if (stage1Nodes.isEmpty) {
      stage1Nodes.add(
        SankeyNode(
          id: 'inflow_total',
          title: 'Total Inflow',
          icon: '💰',
          amount: totalIncome,
          color: AppColors.incomeGreen,
          stage: SankeyStage.inflow,
        ),
      );
    }

    // --- STAGE 2 (Center Hub): Active Wallets / Accounts ---
    final List<SankeyNode> stage2Nodes = [];
    final activeWallets = wallets.isNotEmpty ? wallets.take(3).toList() : [];
    if (activeWallets.isNotEmpty) {
      for (final w in activeWallets) {
        stage2Nodes.add(
          SankeyNode(
            id: 'hub_${w.id}',
            title: w.displayName,
            icon: w.icon,
            amount: max(1.0, w.currentBalance.abs()),
            color: palette.primary,
            stage: SankeyStage.hub,
          ),
        );
      }
    } else {
      stage2Nodes.add(
        SankeyNode(
          id: 'hub_default',
          title: 'Primary Hub',
          icon: '🏦',
          amount: totalIncome,
          color: palette.primary,
          stage: SankeyStage.hub,
        ),
      );
    }

    // --- STAGE 3 (Right): Outflows & Net Savings ---
    final List<SankeyNode> stage3Nodes = [];
    final activeCategories = categories
        .where((c) => (spendingMap[c.id] ?? 0.0) > 0)
        .toList()
      ..sort((a, b) => (spendingMap[b.id] ?? 0.0).compareTo(spendingMap[a.id] ?? 0.0));

    final topCategories = activeCategories.take(3).toList();
    final otherCategories = activeCategories.skip(3).toList();
    final otherTotal = otherCategories.fold(0.0, (sum, c) => sum + (spendingMap[c.id] ?? 0.0));

    for (final cat in topCategories) {
      final amt = spendingMap[cat.id] ?? 0.0;
      stage3Nodes.add(
        SankeyNode(
          id: 'outflow_${cat.id}',
          title: cat.name,
          icon: cat.icon,
          amount: amt,
          color: cat.color,
          stage: SankeyStage.outflow,
        ),
      );
    }

    if (otherTotal > 0) {
      stage3Nodes.add(
        SankeyNode(
          id: 'outflow_other_bundled',
          title: 'Other',
          icon: '📦',
          amount: otherTotal,
          color: AppColors.accentOrange,
          stage: SankeyStage.outflow,
        ),
      );
    }

    if (netSavings > 0 || totalExpense == 0) {
      stage3Nodes.add(
        SankeyNode(
          id: 'net_savings',
          title: 'Net Savings',
          icon: '🌱',
          amount: netSavings > 0 ? netSavings : totalIncome,
          color: const Color(0xFF00E676),
          stage: SankeyStage.outflow,
        ),
      );
    }

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
                    '3-Stage Money Flow (Sankey)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '3-STAGE FLOW',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: palette.primary, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Inflow sources ➔ Accounts hub ➔ Category outflows & net savings retention.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Stage Column Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('INFLOWS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.incomeGreen)),
              Text('ACCOUNTS HUB', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: palette.primary)),
              Text('OUTFLOWS & SAVINGS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.accentOrange)),
            ],
          ),
          const SizedBox(height: 8),

          // 3-Stage Animated Diagram Canvas
          SizedBox(
            height: 260,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _ThreeStageSankeyPainter(
                    stage1Nodes: stage1Nodes,
                    stage2Nodes: stage2Nodes,
                    stage3Nodes: stage3Nodes,
                    progress: _animController.value,
                    selectedNodeId: _selectedNodeId,
                    isDark: isDark,
                  ),
                  child: Row(
                    children: [
                      // Stage 1: Inflow Sources (Left)
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: stage1Nodes.map((node) {
                            return _buildNodeCard(node, settings, isDark);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stage 2: Accounts Hub (Center)
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: stage2Nodes.map((node) {
                            return _buildNodeCard(node, settings, isDark);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stage 3: Outflows & Savings (Right)
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: stage3Nodes.map((node) {
                            return _buildNodeCard(node, settings, isDark);
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

  Widget _buildNodeCard(SankeyNode node, dynamic settings, bool isDark) {
    final isSelected = _selectedNodeId == node.id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
            Text(node.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    settings.formatCurrency(node.amount),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: node.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _ThreeStageSankeyPainter extends CustomPainter {
  final List<SankeyNode> stage1Nodes;
  final List<SankeyNode> stage2Nodes;
  final List<SankeyNode> stage3Nodes;
  final double progress;
  final String? selectedNodeId;
  final bool isDark;

  _ThreeStageSankeyPainter({
    required this.stage1Nodes,
    required this.stage2Nodes,
    required this.stage3Nodes,
    required this.progress,
    required this.selectedNodeId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stage1Nodes.isEmpty || stage2Nodes.isEmpty || stage3Nodes.isEmpty) return;

    // Anchor X coordinates
    final double col1RightX = size.width * 0.28;
    final double col2LeftX = size.width * 0.38;
    final double col2RightX = size.width * 0.62;
    final double col3LeftX = size.width * 0.72;

    final n1 = stage1Nodes.length;
    final n2 = stage2Nodes.length;
    final n3 = stage3Nodes.length;

    // Draw Stream 1: Stage 1 (Inflows) -> Stage 2 (Accounts Hub)
    for (int i = 0; i < n1; i++) {
      final node1 = stage1Nodes[i];
      final double y1 = n1 == 1 ? size.height * 0.5 : (size.height * 0.22) + i * ((size.height * 0.56) / (n1 - 1));

      for (int j = 0; j < n2; j++) {
        final node2 = stage2Nodes[j];
        final double y2 = n2 == 1 ? size.height * 0.5 : (size.height * 0.22) + j * ((size.height * 0.56) / (n2 - 1));

        final bool isHighlight = selectedNodeId == null ||
            selectedNodeId == node1.id ||
            selectedNodeId == node2.id;
        final double opacity = (isHighlight ? 0.65 : 0.12) * progress;

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              node1.color.withValues(alpha: opacity),
              node2.color.withValues(alpha: opacity),
            ],
          ).createShader(Rect.fromPoints(Offset(col1RightX, y1), Offset(col2LeftX, y2)));

        final path = Path();
        path.moveTo(col1RightX, y1);
        final cx1 = col1RightX + (col2LeftX - col1RightX) * 0.5;
        final cx2 = col1RightX + (col2LeftX - col1RightX) * 0.5;
        path.cubicTo(
          cx1,
          y1,
          cx2,
          y2,
          col1RightX + (col2LeftX - col1RightX) * progress,
          y1 + (y2 - y1) * progress,
        );
        canvas.drawPath(path, paint);
      }
    }

    // Draw Stream 2: Stage 2 (Accounts Hub) -> Stage 3 (Outflows & Savings)
    for (int j = 0; j < n2; j++) {
      final node2 = stage2Nodes[j];
      final double y2 = n2 == 1 ? size.height * 0.5 : (size.height * 0.22) + j * ((size.height * 0.56) / (n2 - 1));

      for (int k = 0; k < n3; k++) {
        final node3 = stage3Nodes[k];
        final double y3 = n3 == 1 ? size.height * 0.5 : (size.height * 0.14) + k * ((size.height * 0.72) / (n3 - 1));

        final bool isHighlight = selectedNodeId == null ||
            selectedNodeId == node2.id ||
            selectedNodeId == node3.id;
        final double opacity = (isHighlight ? 0.65 : 0.12) * progress;

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              node2.color.withValues(alpha: opacity),
              node3.color.withValues(alpha: opacity),
            ],
          ).createShader(Rect.fromPoints(Offset(col2RightX, y2), Offset(col3LeftX, y3)));

        final path = Path();
        path.moveTo(col2RightX, y2);
        final cx1 = col2RightX + (col3LeftX - col2RightX) * 0.5;
        final cx2 = col2RightX + (col3LeftX - col2RightX) * 0.5;
        path.cubicTo(
          cx1,
          y2,
          cx2,
          y3,
          col2RightX + (col3LeftX - col2RightX) * progress,
          y2 + (y3 - y2) * progress,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreeStageSankeyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.isDark != isDark;
  }
}
