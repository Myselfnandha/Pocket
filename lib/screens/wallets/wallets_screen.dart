import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/goal_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blurred_dialog_utils.dart';
import '../../widgets/top_capsule_toast.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsWithBalancesProvider);
    final allTxs = ref.watch(transactionsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final settings = ref.watch(settingsProvider);
    final goals = ref.watch(goalsProvider);
    final totalSavedInGoals = ref.watch(totalSavedInGoalsProvider);
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets & Accounts'),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz_rounded, color: palette.primary),
            tooltip: 'Transfer Funds',
            onPressed: () => _showTransferDialog(context, ref, wallets, settings.currencySymbol),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: palette.primary),
            tooltip: 'Add Account',
            onPressed: () => _showAddWalletDialog(context, ref, settings.currencySymbol),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pro Total Balance Header Card (Theme-Adaptive Glowing Hero)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.primary.withValues(alpha: isDark ? 0.16 : 0.09),
                    isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.45 : 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 16, color: palette.primary),
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
                    settings.formatCurrency(totalBalance),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
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
                          color: palette.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '${wallets.length} Active Accounts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ),
                      if (totalSavedInGoals > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🎯 ${settings.formatCurrency(totalSavedInGoals)} Saved',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Wallets List with Edit capability (Zero-inset Column)
            Column(
              children: [
                for (var i = 0; i < wallets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final wallet = wallets[i];
                      final txCount = allTxs.where((t) => t.walletId == wallet.id).length;
                      return InkWell(
                        onTap: () => _showEditWalletModal(context, ref, wallet, settings.currencySymbol),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: wallet.isDefault
                                  ? palette.primary.withValues(alpha: 0.45)
                                  : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                              width: wallet.isDefault ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Account Icon / Emoji
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: wallet.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(wallet.icon, style: const TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 12),

                              // Account Title & Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            wallet.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
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
                                              color: palette.primary.withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: palette.primary,
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
                                    settings.formatCurrency(wallet.currentBalance),
                                    style: TextStyle(
                                      fontSize: 15,
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
                                          Icon(Icons.edit_rounded, size: 12, color: palette.primary),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: palette.primary,
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
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // 3. Savings Goals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Savings Goals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (goals.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${goals.length}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: palette.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: palette.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Goal', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _showAddGoalModal(context, ref, wallets, settings.currencySymbol),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (goals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Column(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      'Start a Savings Goal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set targets for an emergency fund, gadget, vacation, or investment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create My First Goal', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => _showAddGoalModal(context, ref, wallets, settings.currencySymbol),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < goals.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final goal = goals[i];
                        final isDone = goal.isCompleted;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDone
                                  ? palette.primary.withValues(alpha: 0.6)
                                  : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                              width: isDone ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: goal.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(goal.emojiIcon, style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                goal.title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                ),
                                              ),
                                            ),
                                            if (isDone) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: palette.primary.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '🎉 REACHED',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: palette.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          goal.daysRemaining != null
                                              ? '${goal.daysRemaining} days left • Target: ${DateFormat('d MMM yyyy').format(goal.targetDate!)}'
                                              : 'Open-ended goal',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showEditGoalModal(context, ref, goal, wallets, settings.currencySymbol);
                                      } else if (val == 'delete') {
                                        ref.read(goalsProvider.notifier).deleteGoal(goal.id);
                                        TopCapsuleToast.show(
                                          context,
                                          message: 'Goal "${goal.title}" deleted',
                                          isSuccess: false,
                                        );
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit Goal')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete Goal', style: TextStyle(color: AppColors.expenseRed))),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    settings.formatCurrency(goal.currentSavedAmount),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.primary),
                                  ),
                                  Text(
                                    'Target: ${settings.formatCurrency(goal.targetAmount)} (${(goal.progress * 100).toInt()}%)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: goal.progress,
                                  minHeight: 5,
                                  backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
                                  valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: palette.primary.withValues(alpha: 0.15),
                                        foregroundColor: palette.primary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('+ Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                      onPressed: () => _showDepositGoalModal(context, ref, goal, wallets, settings.currencySymbol),
                                    ),
                                  ),
                                  if (goal.currentSavedAmount > 0) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        icon: const Icon(Icons.remove_rounded, size: 16),
                                        label: const Text('- Withdraw', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                        onPressed: () => _showWithdrawGoalModal(context, ref, goal, wallets, settings.currencySymbol),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Add Goal Modal ---
  void _showAddGoalModal(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    final titleCtrl = TextEditingController();
    final targetAmountCtrl = TextEditingController();
    final savedAmountCtrl = TextEditingController(text: '0');
    DateTime? targetDate;
    String? selectedWalletId = wallets.isNotEmpty ? wallets.first.id : null;
    String selectedEmoji = '🎯';
    int selectedColor = 0xFF00E676;

    final emojis = ['🎯', '💻', '🚗', '✈️', '🏠', '📱', '💍', '🎓', '🏥', '💰'];
    final colors = [0xFF00E676, 0xFF2979FF, 0xFFFF9100, 0xFFE040FB, 0xFFFF5252, 0xFF00E5FF];

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Savings Goal',
                          style: TextStyle(
                            fontSize: 18,
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
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'e.g. MacBook Pro, Bali Trip, Emergency Fund',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Target Amount',
                        prefixText: '$currencySymbol ',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: savedAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Initial Saved Amount (Optional)',
                        prefixText: '$currencySymbol ',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Target Deadline Date Picker
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      leading: Icon(Icons.calendar_today_rounded, color: palette.primary),
                      title: Text(
                        targetDate == null
                            ? 'Set Target Date (Optional)'
                            : 'Target Date: ${DateFormat('d MMM yyyy').format(targetDate!)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: targetDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setModalState(() => targetDate = null),
                            )
                          : null,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setModalState(() => targetDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Icon / Emoji', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: emojis.map((emoji) {
                        final isSelected = selectedEmoji == emoji;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedEmoji = emoji),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected ? palette.primary.withValues(alpha: 0.25) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? palette.primary : Colors.transparent, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji, style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Color Theme', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: colors.map((col) {
                        final isSelected = selectedColor == col;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColor = col),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(col),
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Stacked footers: Cancel above Submit
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final target = double.tryParse(targetAmountCtrl.text.trim()) ?? 0.0;
                          final saved = double.tryParse(savedAmountCtrl.text.trim()) ?? 0.0;

                          if (title.isEmpty || target <= 0) {
                            TopCapsuleToast.show(
                              context,
                              message: 'Please enter a valid title and target amount',
                              isSuccess: false,
                            );
                            return;
                          }

                          await ref.read(goalsProvider.notifier).addGoal(
                                title: title,
                                targetAmount: target,
                                currentSavedAmount: saved,
                                targetDate: targetDate,
                                walletId: selectedWalletId,
                                emojiIcon: selectedEmoji,
                                colorValue: selectedColor,
                              );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            TopCapsuleToast.show(
                              context,
                              message: 'Goal "$title" created',
                              isSuccess: true,
                            );
                          }
                        },
                        child: const Text('Create Goal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Deposit to Goal Modal ---
  void _showDepositGoalModal(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    final amountCtrl = TextEditingController();
    String? selectedWalletId = wallets.isNotEmpty ? wallets.first.id : null;

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deposit to ${goal.title}',
                        style: TextStyle(
                          fontSize: 18,
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
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Deposit Amount',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (wallets.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedWalletId,
                      decoration: InputDecoration(
                        labelText: 'Source Wallet',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: wallets.map((w) {
                        return DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.icon} ${w.displayName} ($currencySymbol${w.currentBalance.toStringAsFixed(0)})'),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedWalletId = val),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amount <= 0 || selectedWalletId == null) return;

                        await ref.read(goalsProvider.notifier).depositToGoal(
                              goalId: goal.id,
                              amount: amount,
                              walletId: selectedWalletId!,
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          TopCapsuleToast.show(
                            context,
                            message: 'Deposited $currencySymbol${amount.toStringAsFixed(2)} to ${goal.title}',
                            isSuccess: true,
                          );
                        }
                      },
                      child: const Text('Confirm Deposit', style: TextStyle(fontWeight: FontWeight.w800)),
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

  // --- Withdraw from Goal Modal ---
  void _showWithdrawGoalModal(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    final amountCtrl = TextEditingController(text: goal.currentSavedAmount.toStringAsFixed(0));
    String? selectedWalletId = wallets.isNotEmpty ? wallets.first.id : null;

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Withdraw from ${goal.title}',
                        style: TextStyle(
                          fontSize: 18,
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
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Withdrawal Amount',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (wallets.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedWalletId,
                      decoration: InputDecoration(
                        labelText: 'Deposit Into Wallet',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: wallets.map((w) {
                        return DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.icon} ${w.displayName}'),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedWalletId = val),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentOrange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amount <= 0 || selectedWalletId == null) return;

                        await ref.read(goalsProvider.notifier).withdrawFromGoal(
                              goalId: goal.id,
                              amount: amount,
                              walletId: selectedWalletId!,
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          TopCapsuleToast.show(
                            context,
                            message: 'Withdrew $currencySymbol${amount.toStringAsFixed(2)} from ${goal.title}',
                            isSuccess: true,
                          );
                        }
                      },
                      child: const Text('Confirm Withdrawal', style: TextStyle(fontWeight: FontWeight.w800)),
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

  // --- Edit Goal Modal ---
  void _showEditGoalModal(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    final titleCtrl = TextEditingController(text: goal.title);
    final targetAmountCtrl = TextEditingController(text: goal.targetAmount.toStringAsFixed(0));
    DateTime? targetDate = goal.targetDate;

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Goal',
                        style: TextStyle(
                          fontSize: 18,
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
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Goal Title',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target Amount',
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final target = double.tryParse(targetAmountCtrl.text.trim()) ?? goal.targetAmount;
                        if (title.isEmpty || target <= 0) return;

                        await ref.read(goalsProvider.notifier).updateGoal(
                              goal.copyWith(title: title, targetAmount: target, targetDate: targetDate),
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          TopCapsuleToast.show(
                            context,
                            message: 'Goal "$title" updated',
                            isSuccess: true,
                          );
                        }
                      },
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
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

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Account',
                          style: TextStyle(
                            fontSize: 18,
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
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.black26,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
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
                                color: isSelected ? palette.primary.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? palette.primary : Colors.transparent,
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
                      activeTrackColor: palette.primary,
                      onChanged: (val) => setModalState(() => isDefault = val),
                    ),
                    const SizedBox(height: 20),

                    // Stacked Actions: Cancel above Save, with optional Delete icon
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
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            TopCapsuleToast.show(
                              context,
                              message: 'Please enter an account name',
                              isSuccess: false,
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

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            TopCapsuleToast.show(
                              context,
                              message: 'Account "$name" updated',
                              isSuccess: true,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteWallet(BuildContext context, WidgetRef ref, WalletModel wallet) {
    showBlurredDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.expenseRed.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.expenseRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: AppColors.expenseRed, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Delete "${wallet.displayName}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transactions linked to this wallet will remain in history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(walletsProvider.notifier).deleteWallet(wallet.id);
                      Navigator.pop(ctx);
                      TopCapsuleToast.show(
                        context,
                        message: 'Deleted "${wallet.displayName}"',
                        isSuccess: false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expenseRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New Account',
                          style: TextStyle(
                            fontSize: 18,
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
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.black26,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
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
                                color: isSelected ? palette.primary.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? palette.primary : Colors.transparent,
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
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            TopCapsuleToast.show(
                              context,
                              message: 'Please enter an account name',
                              isSuccess: false,
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
                          TopCapsuleToast.show(
                            context,
                            message: 'Account "$name" created',
                            isSuccess: true,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
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
      TopCapsuleToast.show(
        context,
        message: 'You need at least 2 accounts to transfer funds',
        isSuccess: false,
      );
      return;
    }

    String fromWalletId = wallets[0].id;
    String toWalletId = wallets[1].id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transfer Funds',
                          style: TextStyle(
                            fontSize: 18,
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
                          child: Text('${w.icon} ${w.displayName} (${w.maskedAccountNumber.isNotEmpty ? "${w.maskedAccountNumber} • " : ""}$currencySymbol${w.currentBalance.toStringAsFixed(0)})'),
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
                          child: Text('${w.icon} ${w.displayName} (${w.maskedAccountNumber.isNotEmpty ? "${w.maskedAccountNumber} • " : ""}$currencySymbol${w.currentBalance.toStringAsFixed(0)})'),
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                          if (amount <= 0) {
                            TopCapsuleToast.show(
                              context,
                              message: 'Please enter a valid transfer amount',
                              isSuccess: false,
                            );
                            return;
                          }

                          final fromWallet = wallets.firstWhere((w) => w.id == fromWalletId);
                          final toWallet = wallets.firstWhere((w) => w.id == toWalletId);

                          final now = DateTime.now();
                          final note = noteCtrl.text.trim();

                          ref.read(transactionsProvider.notifier).addTransaction(
                            title: 'Transfer to ${toWallet.displayName}',
                            amount: amount,
                            type: TransactionType.expense,
                            categoryId: 'cat_transfer',
                            walletId: fromWallet.id,
                            date: now,
                            note: note.isNotEmpty ? note : 'Internal Fund Transfer',
                          );

                          ref.read(transactionsProvider.notifier).addTransaction(
                            title: 'Transfer from ${fromWallet.displayName}',
                            amount: amount,
                            type: TransactionType.income,
                            categoryId: 'cat_transfer',
                            walletId: toWallet.id,
                            date: now,
                            note: note.isNotEmpty ? note : 'Internal Fund Transfer',
                          );

                          Navigator.pop(ctx);
                          TopCapsuleToast.show(
                            context,
                            message: 'Transferred $currencySymbol${amount.toStringAsFixed(2)}',
                            isSuccess: true,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
