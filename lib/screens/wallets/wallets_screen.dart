import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            tooltip: 'Add Account',
            onPressed: () => _showAddWalletDialog(context, ref, settings.currencySymbol),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          children: [
            // 1. Pro Total Balance Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 18,
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreenLight.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${wallets.length} Active Accounts',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreenLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Wallets List with Edit capability
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

                return InkWell(
                  onTap: () => _showEditWalletModal(context, ref, wallet, settings.currencySymbol),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: wallet.isDefault
                            ? AppColors.primaryGreenLight.withValues(alpha: 0.45)
                            : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        width: wallet.isDefault ? 1.4 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Account Icon / Emoji
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: wallet.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(wallet.icon, style: const TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 14),

                            // Account Title & Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          wallet.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ),
                                      if (wallet.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreenLight.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'PRIMARY',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryGreenLight,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (wallet.accountNumber != null && wallet.accountNumber!.trim().isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            wallet.maskedAccountNumber,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                      Text(
                                        '$txCount txs • ${wallet.walletType.name.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Balance & Edit Button
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
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
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () => _showEditWalletModal(context, ref, wallet, settings.currencySymbol),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded, size: 12, color: AppColors.primaryGreenLight),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryGreenLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Edit Wallet Modal Bottom Sheet ---
  void _showEditWalletModal(
    BuildContext context,
    WidgetRef ref,
    WalletModel wallet,
    String currencySymbol,
  ) {
    final nameCtrl = TextEditingController(text: wallet.name);
    final last4Ctrl = TextEditingController(text: wallet.accountNumber ?? '');
    final initialBalanceCtrl = TextEditingController(
      text: wallet.initialBalance % 1 == 0
          ? wallet.initialBalance.toInt().toString()
          : wallet.initialBalance.toStringAsFixed(2),
    );
    WalletType selectedType = wallet.walletType;
    String selectedIcon = wallet.icon;
    int selectedColor = wallet.colorValue;
    bool isDefault = wallet.isDefault;

    final icons = ['🏦', '💳', '💵', '📱', '💰', '🪙', '🏧', '📈', '🏠'];
    final colors = [
      0xFF4CAF50, // Green
      0xFF2196F3, // Blue
      0xFF9C27B0, // Purple
      0xFFFF9800, // Orange
      0xFFE91E63, // Pink
      0xFF00BCD4, // Cyan
      0xFF607D8B, // Blue Grey
      0xFFF44336, // Red
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Name
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. HDFC Bank, Salary A/c',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Account Type Selector
                  DropdownButtonFormField<WalletType>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Account Type',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: WalletType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Last 4 Digits of Account Number (Required for Bank & Card)
                  if (selectedType == WalletType.bank || selectedType == WalletType.creditCard || selectedType == WalletType.savings) ...[
                    TextField(
                      controller: last4Ctrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Account Last 4 Digits',
                        hintText: 'e.g. 4821',
                        prefixText: '•••• ',
                        counterText: '',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Initial / Starting Balance
                  TextField(
                    controller: initialBalanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Starting Balance',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Icon Picker
                  Text('Icon / Emoji', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: icons.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final icon = icons[i];
                        final isSelected = selectedIcon == icon;
                        return InkWell(
                          onTap: () => setModalState(() => selectedIcon = icon),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryGreenLight.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryGreenLight : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(icon, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Color Picker
                  Text('Color Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: colors.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final col = colors[i];
                        final isSelected = selectedColor == col;
                        return InkWell(
                          onTap: () => setModalState(() => selectedColor = col),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(col),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Set as Primary Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Primary Account', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Used as default for newly added transactions'),
                    value: isDefault,
                    activeThumbColor: AppColors.primaryGreenLight,
                    onChanged: (val) => setModalState(() => isDefault = val),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons: Save & Delete
                  Row(
                    children: [
                      if (ref.read(walletsProvider).length > 1)
                        IconButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteWallet(context, ref, wallet);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expenseRed),
                          tooltip: 'Delete Account',
                        ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter an account name'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              return;
                            }

                            final initialBal = double.tryParse(initialBalanceCtrl.text.trim()) ?? wallet.initialBalance;
                            final last4 = last4Ctrl.text.trim();

                            final updated = wallet.copyWith(
                              name: name,
                              walletType: selectedType,
                              accountNumber: last4.isNotEmpty ? last4 : null,
                              initialBalance: initialBal,
                              icon: selectedIcon,
                              colorValue: selectedColor,
                              isDefault: isDefault,
                            );

                            // If set as default, unset other defaults
                            if (isDefault && !wallet.isDefault) {
                              final allWallets = ref.read(walletsProvider);
                              for (final w in allWallets) {
                                if (w.id != wallet.id && w.isDefault) {
                                  await ref.read(walletsProvider.notifier).updateWallet(w.copyWith(isDefault: false));
                                }
                              }
                            }

                            await ref.read(walletsProvider.notifier).updateWallet(updated);

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Account "$name" updated successfully'),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreenLight,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteWallet(BuildContext context, WidgetRef ref, WalletModel wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${wallet.name}"?'),
        content: const Text('Are you sure you want to delete this account? Transactions linked to this wallet will remain in history.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(walletsProvider.notifier).deleteWallet(wallet.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${wallet.name}"'),
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Add Wallet Dialog ---
  void _showAddWalletDialog(BuildContext context, WidgetRef ref, String currencySymbol) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    WalletType selectedType = WalletType.bank;
    String selectedIcon = '🏦';
    int selectedColor = 0xFF2196F3;

    final icons = ['🏦', '💳', '💵', '📱', '💰', '🪙', '🏧', '📈', '🏠'];
    final colors = [
      0xFF4CAF50,
      0xFF2196F3,
      0xFF9C27B0,
      0xFFFF9800,
      0xFFE91E63,
      0xFF00BCD4,
      0xFF607D8B,
      0xFFF44336,
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add New Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. ICICI Bank, SBI Savings',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WalletType>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Account Type',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: WalletType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedType == WalletType.bank || selectedType == WalletType.creditCard || selectedType == WalletType.savings) ...[
                    TextField(
                      controller: last4Ctrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Account Last 4 Digits',
                        hintText: 'e.g. 4821',
                        prefixText: '•••• ',
                        counterText: '',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Initial Balance',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Icon / Emoji', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: icons.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final icon = icons[i];
                        final isSelected = selectedIcon == icon;
                        return InkWell(
                          onTap: () => setModalState(() => selectedIcon = icon),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryGreenLight.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryGreenLight : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(icon, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Color Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: colors.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final col = colors[i];
                        final isSelected = selectedColor == col;
                        return InkWell(
                          onTap: () => setModalState(() => selectedColor = col),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(col),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an account name'),
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        final bal = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                        final last4 = last4Ctrl.text.trim();

                        final newWallet = WalletModel(
                          id: const Uuid().v4(),
                          name: name,
                          icon: selectedIcon,
                          colorValue: selectedColor,
                          initialBalance: bal,
                          currentBalance: bal,
                          walletType: selectedType,
                          accountNumber: last4.isNotEmpty ? last4 : null,
                        );

                        ref.read(walletsProvider.notifier).addWallet(newWallet);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Account "$name" created successfully'),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreenLight,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Transfer Funds Dialog ---
  void _showTransferDialog(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 2 accounts to transfer funds'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    String fromWalletId = wallets[0].id;
    String toWalletId = wallets[1].id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: const Text('Transfer Funds', style: TextStyle(fontWeight: FontWeight.w800)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: fromWalletId,
                    decoration: InputDecoration(
                      labelText: 'From Account',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: wallets.map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.icon} ${w.name} (${w.maskedAccountNumber.isNotEmpty ? "${w.maskedAccountNumber} • " : ""}$currencySymbol${w.currentBalance.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          fromWalletId = val;
                          if (toWalletId == val) {
                            toWalletId = wallets.firstWhere((w) => w.id != val).id;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: toWalletId,
                    decoration: InputDecoration(
                      labelText: 'To Account',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: wallets.where((w) => w.id != fromWalletId).map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.icon} ${w.name} (${w.maskedAccountNumber.isNotEmpty ? "${w.maskedAccountNumber} • " : ""}$currencySymbol${w.currentBalance.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => toWalletId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Transfer Amount',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'e.g. ATM cash withdrawal',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid transfer amount'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  final fromWallet = wallets.firstWhere((w) => w.id == fromWalletId);
                  final toWallet = wallets.firstWhere((w) => w.id == toWalletId);

                  // Create transfer out expense & transfer in income
                  final now = DateTime.now();
                  final note = noteCtrl.text.trim();

                  ref.read(transactionsProvider.notifier).addTransaction(
                    title: 'Transfer to ${toWallet.name}',
                    amount: amount,
                    type: TransactionType.expense,
                    categoryId: 'cat_transfer',
                    walletId: fromWallet.id,
                    date: now,
                    note: note.isNotEmpty ? note : 'Internal Fund Transfer',
                  );

                  ref.read(transactionsProvider.notifier).addTransaction(
                    title: 'Transfer from ${fromWallet.name}',
                    amount: amount,
                    type: TransactionType.income,
                    categoryId: 'cat_transfer',
                    walletId: toWallet.id,
                    date: now,
                    note: note.isNotEmpty ? note : 'Internal Fund Transfer',
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transferred $currencySymbol${amount.toStringAsFixed(2)} successfully'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenLight,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }
}
