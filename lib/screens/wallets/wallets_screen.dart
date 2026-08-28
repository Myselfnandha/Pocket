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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Pro Total Balance Header Card (Enlarged to fill grid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primaryGreenLight),
                      const SizedBox(width: 6),
                      Text(
                        'Net Liquid Balance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${settings.currencySymbol}${currencyFormat.format(totalBalance)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreenLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreenLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${wallets.length} Active Accounts Available',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreenLight,
                      ),
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
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: wallet.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
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
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$txCount transactions • ${wallet.walletType.name.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${settings.currencySymbol}${currencyFormat.format(wallet.currentBalance)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
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
                          minHeight: 5,
                          backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation<Color>(wallet.color),
                        ),
                      ),
                      if (wallet.spendingLimit != null && wallet.spendingLimit! > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Limit: ${settings.currencySymbol}${currencyFormat.format(wallet.spendingLimit!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 80), // space for FAB
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

    final icons = ['💵', '🏦', '📱', '💳', '💰', '🪙', '💼'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Setup New Wallet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: WalletType.values.map((type) {
                    final isSel = selectedType == type;
                    return ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: isSel,
                      onSelected: (_) {
                        setDialogState(() {
                          selectedType = type;
                          if (type == WalletType.cash) selectedIcon = '💵';
                          if (type == WalletType.bank) selectedIcon = '🏦';
                          if (type == WalletType.upi) selectedIcon = '📱';
                          if (type == WalletType.creditCard) selectedIcon = '💳';
                          if (type == WalletType.savings) selectedIcon = '💰';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Wallet Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. HDFC Salary Bank'),
                ),
                const SizedBox(height: 14),
                Text('Starting Balance ($currencySymbol)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currencySymbol ',
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Set Spending Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Switch(
                      value: enableLimit,
                      activeThumbColor: AppColors.primaryGreenLight,
                      onChanged: (val) => setDialogState(() => enableLimit = val),
                    ),
                  ],
                ),
                if (enableLimit) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '$currencySymbol ',
                      hintText: 'Monthly limit (e.g. 50000)',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Choose Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
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
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
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

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Wallet "$name" added ✓'), duration: const Duration(seconds: 4)),
                );
              },
              child: const Text('Save Wallet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, List<WalletModel> wallets, String currencySymbol) {
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 wallets are required to transfer funds'), duration: Duration(seconds: 4)),
      );
      return;
    }

    String fromWalletId = wallets.first.id;
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
                    const SnackBar(content: Text('Please enter a valid amount'), duration: Duration(seconds: 4)),
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
                    duration: const Duration(seconds: 4),
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
