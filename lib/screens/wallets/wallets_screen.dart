import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/transaction_tile.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  int _selectedWalletIndex = 0;
  late final PageController _pageController;
  String _transactionFilter = 'all'; // 'all', 'expense', 'income'

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.90);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  LinearGradient _getCardGradient(WalletModel wallet) {
    final type = wallet.walletType;

    switch (type) {
      case WalletType.cash:
        return const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WalletType.bank:
        return const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF0288D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WalletType.upi:
        return const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WalletType.creditCard:
        return const LinearGradient(
          colors: [Color(0xFF212121), Color(0xFF37474F), Color(0xFF263238)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WalletType.savings:
        return const LinearGradient(
          colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsWithBalancesProvider);
    final allTxs = ref.watch(transactionsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currencyFormat = NumberFormat('#,##0.00');

    if (_selectedWalletIndex >= wallets.length && wallets.isNotEmpty) {
      _selectedWalletIndex = 0;
    }

    final activeWallet = wallets.isNotEmpty ? wallets[_selectedWalletIndex] : null;

    // Filter transactions for active wallet
    final walletTxs = activeWallet != null
        ? allTxs.where((tx) => tx.walletId == activeWallet.id).toList()
        : <TransactionModel>[];

    final filteredTxs = walletTxs.where((tx) {
      if (_transactionFilter == 'expense') return tx.type == TransactionType.expense;
      if (_transactionFilter == 'income') return tx.type == TransactionType.income;
      return true;
    }).toList();

    // Calculate Wallet Cash Flow
    double totalWalletIn = 0.0;
    double totalWalletOut = 0.0;
    for (final tx in walletTxs) {
      if (tx.type == TransactionType.income) totalWalletIn += tx.amount;
      if (tx.type == TransactionType.expense) totalWalletOut += tx.amount;
    }
    final netWalletFlow = totalWalletIn - totalWalletOut;

    // Calculate spending limit metrics for active wallet
    double currentMonthSpent = 0.0;
    if (activeWallet?.spendingLimit != null && activeWallet!.spendingLimit! > 0) {
      final now = DateTime.now();
      for (final tx in walletTxs) {
        if (tx.type == TransactionType.expense &&
            tx.date.year == now.year &&
            tx.date.month == now.month) {
          currentMonthSpent += tx.amount;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets & Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryGreenLight),
            tooltip: 'Transfer Funds',
            onPressed: () => _showTransferDialog(context, ref, wallets, settings.currencySymbol),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
            tooltip: 'Add Wallet',
            onPressed: () => _showAddWalletDialog(context, ref, settings.currencySymbol),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Total Balance Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primaryGreenLight),
                              const SizedBox(width: 6),
                              Text(
                                'Net Liquid Balance',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${settings.currencySymbol}${currencyFormat.format(totalBalance)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryGreenLight,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${wallets.length} Accounts',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreenLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Realistic Visual Card Carousel
            if (wallets.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: wallets.length,
                  onPageChanged: (index) {
                    setState(() => _selectedWalletIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    final isSelected = index == _selectedWalletIndex;
                    return AnimatedScale(
                      scale: isSelected ? 1.0 : 0.94,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _buildRealisticCard(wallet, settings.currencySymbol, currencyFormat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Card Carousel Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(wallets.length, (index) {
                  final isSelected = index == _selectedWalletIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isSelected ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryGreenLight : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Selected Card Quick Actions Hub
            if (activeWallet != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionPill(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Transfer',
                        color: AppColors.primaryGreenLight,
                        onTap: () => _showTransferDialog(context, ref, wallets, settings.currencySymbol),
                      ),
                      _buildActionPill(
                        icon: Icons.tune_rounded,
                        label: 'Adjust Bal',
                        color: AppColors.infoBlue,
                        onTap: () => _showReconcileDialog(context, ref, activeWallet, settings.currencySymbol),
                      ),
                      _buildActionPill(
                        icon: Icons.speed_rounded,
                        label: 'Set Limit',
                        color: AppColors.accentOrange,
                        onTap: () => _showSpendingLimitDialog(context, ref, activeWallet, settings.currencySymbol),
                      ),
                      _buildActionPill(
                        icon: Icons.edit_rounded,
                        label: 'Edit Card',
                        color: Colors.grey,
                        onTap: () => _showEditWalletDialog(context, ref, activeWallet),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Monthly Spending Limit Progress Bar
            if (activeWallet?.spendingLimit != null && activeWallet!.spendingLimit! > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSpendingLimitCard(activeWallet, currentMonthSpent, settings.currencySymbol, currencyFormat, isDark),
              ),
              const SizedBox(height: 16),
            ],

            // 5. Wallet-Specific Activity Statement
            if (activeWallet != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cash Flow Summary Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildFlowMetric(
                            label: 'Total In',
                            amount: totalWalletIn,
                            color: AppColors.incomeGreen,
                            icon: Icons.arrow_downward_rounded,
                            symbol: settings.currencySymbol,
                            format: currencyFormat,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFlowMetric(
                            label: 'Total Out',
                            amount: totalWalletOut,
                            color: AppColors.expenseRed,
                            icon: Icons.arrow_upward_rounded,
                            symbol: settings.currencySymbol,
                            format: currencyFormat,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFlowMetric(
                            label: 'Net Flow',
                            amount: netWalletFlow,
                            color: netWalletFlow >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                            icon: Icons.swap_vert_rounded,
                            symbol: settings.currencySymbol,
                            format: currencyFormat,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section Title & Filter Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${activeWallet.name} Statement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            _buildFilterChip('all', 'All'),
                            const SizedBox(width: 4),
                            _buildFilterChip('expense', 'Spent'),
                            const SizedBox(width: 4),
                            _buildFilterChip('income', 'Inflow'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Statement Transaction List
                    if (filteredTxs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'No transactions for ${activeWallet.name}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTxs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = filteredTxs[index];
                          return TransactionTile(
                            transaction: tx,
                            onTap: () => context.push('/transaction/${tx.id}'),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRealisticCard(WalletModel wallet, String currencySymbol, NumberFormat currencyFormat) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getCardGradient(wallet),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: wallet.color.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Background Card Brand Icon Watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.14,
              child: Text(
                wallet.icon,
                style: const TextStyle(fontSize: 100),
              ),
            ),
          ),

          // Main Card Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Wallet Icon & Name + Contactless / Card Type Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(wallet.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      wallet.walletType.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              // EMV Chip & Contactless Icon
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                    ),
                    child: const Icon(Icons.credit_card, color: Color(0xFF795548), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.contactless_rounded, color: Colors.white70, size: 22),
                ],
              ),

              // Bottom Row: Balance Label & Formatted Big Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currencySymbol${currencyFormat.format(wallet.currentBalance)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingLimitCard(
    WalletModel wallet,
    double currentMonthSpent,
    String currencySymbol,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final limit = wallet.spendingLimit!;
    final ratio = (currentMonthSpent / limit).clamp(0.0, 1.0);
    final percentage = (currentMonthSpent / limit * 100).toInt();
    final isExceeded = currentMonthSpent > limit;
    final isWarning = currentMonthSpent >= limit * 0.8 && !isExceeded;

    final statusColor = isExceeded
        ? AppColors.expenseRed
        : (isWarning ? AppColors.accentOrange : AppColors.incomeGreen);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: statusColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Monthly Budget Cap',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExceeded ? 'Over Budget' : '$percentage% Used',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: $currencySymbol${currencyFormat.format(currentMonthSpent)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Limit: $currencySymbol${currencyFormat.format(limit)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowMetric({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required String symbol,
    required NumberFormat format,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$symbol${format.format(amount.abs())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _transactionFilter == value;
    return InkWell(
      onTap: () => setState(() => _transactionFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreenLight.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreenLight : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primaryGreenLight : Colors.grey,
          ),
        ),
      ),
    );
  }

  // --- Modals & Dialogs ---

  void _showReconcileDialog(BuildContext context, WidgetRef ref, WalletModel wallet, String currencySymbol) {
    final balanceCtrl = TextEditingController(text: wallet.currentBalance.toStringAsFixed(2));
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust ${wallet.name} Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Directly calibrate this wallet to match your actual cash in hand or bank account.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                labelText: 'Actual Current Balance',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Adjustment Reason (Optional)',
                hintText: 'e.g. Physical cash count, ATM withdrawal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreenLight, foregroundColor: Colors.black),
            onPressed: () async {
              final newBal = double.tryParse(balanceCtrl.text.trim());
              if (newBal == null) return;

              // Calculate difference
              final diff = newBal - wallet.currentBalance;
              if (diff.abs() > 0.001) {
                // Adjust initial balance so reactive calculation equals newBal
                final updatedWallet = wallet.copyWith(
                  initialBalance: wallet.initialBalance + diff,
                  currentBalance: newBal,
                );
                await ref.read(walletsProvider.notifier).updateWallet(updatedWallet);
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ ${wallet.name} balance calibrated to $currencySymbol${newBal.toStringAsFixed(2)}')),
              );
            },
            child: const Text('Calibrate Balance'),
          ),
        ],
      ),
    );
  }

  void _showSpendingLimitDialog(BuildContext context, WidgetRef ref, WalletModel wallet, String currencySymbol) {
    final limitCtrl = TextEditingController(
      text: wallet.spendingLimit != null ? wallet.spendingLimit!.toStringAsFixed(0) : '',
    );
    bool enableLimit = wallet.spendingLimit != null && wallet.spendingLimit! > 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Monthly Budget Cap: ${wallet.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Enable Spending Cap', style: TextStyle(fontWeight: FontWeight.w600)),
                  Switch(
                    value: enableLimit,
                    activeThumbColor: AppColors.primaryGreenLight,
                    onChanged: (val) => setDialogState(() => enableLimit = val),
                  ),
                ],
              ),
              if (enableLimit) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currencySymbol ',
                    labelText: 'Monthly Spending Cap',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreenLight, foregroundColor: Colors.black),
              onPressed: () async {
                final limit = enableLimit ? double.tryParse(limitCtrl.text.trim()) : null;
                final updatedWallet = wallet.copyWith(spendingLimit: limit);
                await ref.read(walletsProvider.notifier).updateWallet(updatedWallet);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Save Limit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditWalletDialog(BuildContext context, WidgetRef ref, WalletModel wallet) {
    final nameCtrl = TextEditingController(text: wallet.name);
    String selectedIcon = wallet.icon;
    const icons = ['🏦', '💵', '💳', '📱', '💰', '🪙', '💼', '🏧'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Wallet Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: icons.map((icon) {
                  final isSel = selectedIcon == icon;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primaryGreenLight.withValues(alpha: 0.25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSel ? Border.all(color: AppColors.primaryGreenLight) : null,
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (!wallet.isDefault)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.expenseRed),
                onPressed: () async {
                  await ref.read(walletsProvider.notifier).deleteWallet(wallet.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
                child: const Text('Delete'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreenLight, foregroundColor: Colors.black),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final updated = wallet.copyWith(name: name, icon: selectedIcon);
                await ref.read(walletsProvider.notifier).updateWallet(updated);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref, String currencySymbol) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    WalletType selectedType = WalletType.bank;
    String selectedIcon = '🏦';
    bool enableLimit = false;
    const icons = ['🏦', '💵', '💳', '📱', '💰', '🪙', '💼', '🏧'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    hintText: 'e.g. HDFC Salary, Cash, GPay',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WalletType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Account Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: WalletType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                        if (val == WalletType.cash) selectedIcon = '💵';
                        if (val == WalletType.upi) selectedIcon = '📱';
                        if (val == WalletType.creditCard) selectedIcon = '💳';
                        if (val == WalletType.bank) selectedIcon = '🏦';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currencySymbol ',
                    labelText: 'Starting Balance',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Spending Cap', style: TextStyle(fontWeight: FontWeight.w600)),
                    Switch(
                      value: enableLimit,
                      activeThumbColor: AppColors.primaryGreenLight,
                      onChanged: (val) => setDialogState(() => enableLimit = val),
                    ),
                  ],
                ),
                if (enableLimit) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '$currencySymbol ',
                      labelText: 'Monthly Limit',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Choose Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: icons.map((icon) {
                    final isSel = selectedIcon == icon;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primaryGreenLight.withValues(alpha: 0.25) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSel ? Border.all(color: AppColors.primaryGreenLight) : null,
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreenLight, foregroundColor: Colors.black),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final startBal = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                final limit = enableLimit ? double.tryParse(limitCtrl.text.trim()) : null;

                final newWallet = WalletModel(
                  id: const Uuid().v4(),
                  name: name,
                  icon: selectedIcon,
                  colorValue: 0xFF2E7D32,
                  initialBalance: startBal,
                  currentBalance: startBal,
                  walletType: selectedType,
                  spendingLimit: limit,
                );

                await ref.read(walletsProvider.notifier).addWallet(newWallet);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, List<WalletModel> wallets, String currencySymbol) {
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 accounts are required to transfer funds'), duration: Duration(seconds: 4)),
      );
      return;
    }

    String fromWalletId = wallets.first.id;
    String toWalletId = wallets[1].id;
    final amountController = TextEditingController();
    final currencyFormat = NumberFormat('#,##0.00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fromWallet = wallets.firstWhere((w) => w.id == fromWalletId, orElse: () => wallets.first);
          final toWallet = wallets.firstWhere((w) => w.id == toWalletId, orElse: () => wallets.last);
          final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
          final isExceedingBalance = enteredAmount > fromWallet.currentBalance && fromWallet.currentBalance >= 0;

          return AlertDialog(
            title: const Text('Transfer Between Accounts'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: fromWalletId,
                    items: wallets.map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.icon} ${w.name} ($currencySymbol${currencyFormat.format(w.currentBalance)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          fromWalletId = val;
                          if (toWalletId == fromWalletId) {
                            toWalletId = wallets.firstWhere((w) => w.id != fromWalletId).id;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text('To Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: toWalletId,
                    items: wallets.where((w) => w.id != fromWalletId).map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.icon} ${w.name} ($currencySymbol${currencyFormat.format(w.currentBalance)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => toWalletId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Amount ($currencySymbol)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '$currencySymbol ',
                      hintText: '0.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (isExceedingBalance) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Warning: Amount exceeds source balance',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.expenseRed),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreenLight, foregroundColor: Colors.black),
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amount <= 0) return;

                  await ref.read(transactionsProvider.notifier).addTransaction(
                        title: 'Transfer to ${toWallet.name}',
                        amount: amount,
                        type: TransactionType.expense,
                        categoryId: 'other',
                        walletId: fromWallet.id,
                        date: DateTime.now(),
                        note: 'Transfer to ${toWallet.name}',
                      );

                  await ref.read(transactionsProvider.notifier).addTransaction(
                        title: 'Transfer from ${fromWallet.name}',
                        amount: amount,
                        type: TransactionType.income,
                        categoryId: 'other',
                        walletId: toWallet.id,
                        date: DateTime.now(),
                        note: 'Transfer from ${fromWallet.name}',
                      );

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
                child: const Text('Complete Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
