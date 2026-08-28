import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsWithBalancesProvider);
    final allTxs = ref.watch(transactionsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets & Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryGreenLight),
            tooltip: 'Transfer Money',
            onPressed: () => _showTransferDialog(context, ref, wallets, settings.currencySymbol),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Total Balance Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Net Liquid Balance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${settings.currencySymbol}${currencyFormat.format(totalBalance)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreenLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Across ${wallets.length} active wallets',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Wallets List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wallets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final wallet = wallets[index];
                final txCount = allTxs.where((t) => t.walletId == wallet.id).length;
                final percentage = totalBalance > 0
                    ? (wallet.currentBalance / totalBalance).clamp(0.0, 1.0)
                    : 0.0;

                return Container(
                  padding: const EdgeInsets.all(16),
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: wallet.color.withValues(alpha: isDark ? 0.25 : 0.15),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(wallet.icon, style: const TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wallet.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$txCount transactions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${settings.currencySymbol}${currencyFormat.format(wallet.currentBalance)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: wallet.currentBalance >= 0
                                  ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                  : AppColors.expenseRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(wallet.color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Add Wallet Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(
                  color: AppColors.primaryGreenLight,
                  style: BorderStyle.solid,
                ),
              ),
              icon: const Icon(Icons.add_rounded, color: AppColors.primaryGreenLight),
              label: const Text(
                'Add New Wallet',
                style: TextStyle(
                  color: AppColors.primaryGreenLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _showAddWalletDialog(context, ref),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String selectedIcon = '🏦';
    int selectedColor = 0xFF4CAF50;

    final icons = ['💵', '🏦', '💳', '📱', '💰', '🎯', '🏪', '✈️'];
    final colors = [
      0xFF4CAF50,
      0xFF2196F3,
      0xFFFF9800,
      0xFF9C27B0,
      0xFFE91E63,
      0xFF00BCD4,
      0xFF795548,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Name Field
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g. Savings Account, Paytm',
                ),
              ),
              const SizedBox(height: 12),

              // Initial Balance Field
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Initial Balance',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 16),

              // Icon Selector
              const Text('Select Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: icons.map((icon) {
                  final isSel = selectedIcon == icon;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primaryGreenLight.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSel ? Border.all(color: AppColors.primaryGreenLight, width: 1.5) : null,
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Color Selector
              const Text('Select Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: colors.map((c) {
                  final isSel = selectedColor == c;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = c),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                      ),
                      child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final initialBal = double.tryParse(balanceController.text.trim()) ?? 0.0;

                    ref.read(walletsProvider.notifier).addWallet(
                          WalletModel(
                            id: const Uuid().v4(),
                            name: name,
                            icon: selectedIcon,
                            colorValue: selectedColor,
                            initialBalance: initialBal,
                            currentBalance: initialBal,
                          ),
                        );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Create Wallet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDialog(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least 2 wallets to transfer funds.')),
      );
      return;
    }

    String fromWalletId = wallets[0].id;
    String toWalletId = wallets[1].id;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Transfer Funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('From Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: fromWalletId,
                items: wallets.map((w) {
                  return DropdownMenuItem(
                    value: w.id,
                    child: Text('${w.icon} ${w.name}'),
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
              const SizedBox(height: 16),
              const Text('To Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: toWalletId,
                items: wallets.where((w) => w.id != fromWalletId).map((w) {
                  return DropdownMenuItem(
                    value: w.id,
                    child: Text('${w.icon} ${w.name}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => toWalletId = val);
                },
              ),
              const SizedBox(height: 16),
              Text('Transfer Amount ($currencySymbol)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '$currencySymbol ',
                  hintText: '0.00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                final fromWallet = wallets.firstWhere((w) => w.id == fromWalletId);
                final toWallet = wallets.firstWhere((w) => w.id == toWalletId);

                // Add transfer expense from source
                await ref.read(transactionsProvider.notifier).addTransaction(
                      title: 'Transfer to ${toWallet.name}',
                      amount: amount,
                      type: TransactionType.expense,
                      categoryId: 'other',
                      walletId: fromWallet.id,
                      date: DateTime.now(),
                      note: 'Inter-account fund transfer',
                    );

                // Add transfer income to destination
                await ref.read(transactionsProvider.notifier).addTransaction(
                      title: 'Transfer from ${fromWallet.name}',
                      amount: amount,
                      type: TransactionType.income,
                      categoryId: 'other',
                      walletId: toWallet.id,
                      date: DateTime.now(),
                      note: 'Inter-account fund transfer',
                    );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Transferred $currencySymbol${amount.toStringAsFixed(2)} from ${fromWallet.name} to ${toWallet.name} ✓'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}
