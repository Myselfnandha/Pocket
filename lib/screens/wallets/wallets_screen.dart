import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/goal_model.dart';
import '../../models/settings_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blurred_dialog_utils.dart';
import '../../widgets/top_capsule_toast.dart';
import '../../widgets/transaction_tile.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  int _selectedAccountIndex = 0;
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsWithBalancesProvider);
    final allTxs = ref.watch(transactionsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final settings = ref.watch(settingsProvider);
    final goals = ref.watch(goalsProvider);
    final totalSavedInGoals = ref.watch(totalSavedInGoalsProvider);
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final regularWallets = wallets.where((w) => w.type != WalletType.loan).toList();
    final loanWallets = wallets.where((w) => w.type == WalletType.loan).toList();

    final activeIndex = regularWallets.isNotEmpty
        ? _selectedAccountIndex.clamp(0, regularWallets.length - 1)
        : 0;
    final activeWallet = regularWallets.isNotEmpty ? regularWallets[activeIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets & Accounts'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Option 1: Combined Total Balance Executive Card
            _buildVaultExecutiveCard(
              context: context,
              ref: ref,
              totalBalance: totalBalance,
              wallets: regularWallets,
              settings: settings,
              palette: palette,
              isDark: isDark,
              activeWallet: activeWallet,
            ),
            const SizedBox(height: 22),

            if (loanWallets.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1708) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('📜', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${loanWallets.length} loan accounts tracked in Debts & Loans',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        foregroundColor: isDark ? Colors.amber : Colors.amber.shade800,
                      ),
                      onPressed: () => context.push('/debts'),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_rounded, size: 13),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Stacked Account Deck for Each Account
              _buildAccountStack(context, regularWallets, activeIndex, settings, palette, isDark),
              const SizedBox(height: 16),

              // 2. 4-Action Quick Bar ("Send", "Request", "TopUp", "More")
              _buildQuickActionDock(
                context: context,
                ref: ref,
                activeWallet: activeWallet,
                wallets: regularWallets,
                settings: settings,
                palette: palette,
                isDark: isDark,
              ),
              const SizedBox(height: 22),

              // 3. Active Account Activity
              _buildAccountActivitySection(
                context,
                ref,
                activeWallet,
                allTxs,
                palette,
                isDark,
              ),
              const SizedBox(height: 26),

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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
    final currentBalanceCtrl = TextEditingController(
      text: wallet.currentBalance % 1 == 0
          ? wallet.currentBalance.toInt().toString()
          : wallet.currentBalance.toStringAsFixed(2),
    );
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                        'Edit Account',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 1: Account Name + Account Type
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            labelText: 'Account Name',
                            hintText: 'e.g. HDFC Bank',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<WalletType>(
                          initialValue: selectedType,
                          isDense: true,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Type',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Last 4 digits (if applicable) + Current Balance + Starting Balance
                  Row(
                    children: [
                      if (selectedType == WalletType.bank || selectedType == WalletType.creditCard || selectedType == WalletType.savings) ...[
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: last4Ctrl,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Last 4',
                              hintText: '4821',
                              prefixText: '•• ',
                              counterText: '',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: TextField(
                          controller: currentBalanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Current Balance',
                            prefixText: '$currencySymbol ',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 3: Emoji Selector
                  Row(
                    children: [
                      Text(
                        'Icon:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await _showSystemEmojiPicker(context, selectedIcon);
                          if (picked != null && picked.isNotEmpty) {
                            setModalState(() => selectedIcon = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(selectedIcon, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Text('Pick Any Emoji', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.primary)),
                              const SizedBox(width: 3),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: palette.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: icons.length,
                            separatorBuilder: (context, i) => const SizedBox(width: 6),
                            itemBuilder: (context, i) {
                              final icon = icons[i];
                              final isSelected = selectedIcon == icon;
                              return InkWell(
                                onTap: () => setModalState(() => selectedIcon = icon),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected ? palette.primary.withValues(alpha: 0.25) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? palette.primary : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(icon, style: const TextStyle(fontSize: 18)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 4: Colors
                  Row(
                    children: [
                      Text(
                        'Color:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: colors.length + 1,
                            separatorBuilder: (context, i) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              if (i == colors.length) {
                                return InkWell(
                                  onTap: () async {
                                    final custom = await _showCustomColorPicker(context, selectedColor);
                                    if (custom != null) {
                                      setModalState(() => selectedColor = custom);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF282B34) : Colors.grey.shade200,
                                      border: Border.all(
                                        color: isDark ? Colors.white24 : Colors.black26,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 16),
                                  ),
                                );
                              }
                              final col = colors[i];
                              final isSelected = selectedColor == col;
                              return InkWell(
                                onTap: () => setModalState(() => selectedColor = col),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Color(col),
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                                  ),
                                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Row 5: Set as Primary Switch
                  InkWell(
                    onTap: () => setModalState(() => isDefault = !isDefault),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Primary Account',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'Default for newly added transactions',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isDefault,
                            activeTrackColor: palette.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => setModalState(() => isDefault = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 6: Single-row actions: Delete icon + Cancel + Save
                  Row(
                    children: [
                      if (ref.read(walletsProvider).length > 1) ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteWallet(context, ref, wallet);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expenseRed, size: 20),
                          tooltip: 'Delete Account',
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
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
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 24,
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
  void _showAddWalletDialog(BuildContext context, WidgetRef ref, String currencySymbol, {WalletType initialType = WalletType.bank}) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    WalletType selectedType = initialType;
    String selectedIcon = initialType == WalletType.loan ? '📜' : '🏦';
    int selectedColor = initialType == WalletType.loan ? 0xFFFF9800 : 0xFF2196F3;

    final icons = ['🏦', '💳', '💵', '📱', '💰', '🪙', '🏧', '📈', '🏠', '📜'];
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                          child: Text(type.displayName.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedType == WalletType.bank || selectedType == WalletType.creditCard || selectedType == WalletType.savings || selectedType == WalletType.loan) ...[
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
    String currencySymbol, {
    String? initialFromWalletId,
    String? initialToWalletId,
  }) {
    if (wallets.length < 2) {
      TopCapsuleToast.show(
        context,
        message: 'You need at least 2 accounts to transfer funds',
        isSuccess: false,
      );
      return;
    }

    String toWalletId = initialToWalletId != null && wallets.any((w) => w.id == initialToWalletId)
        ? initialToWalletId
        : wallets.last.id;
    String fromWalletId = initialFromWalletId != null && wallets.any((w) => w.id == initialFromWalletId && w.id != toWalletId)
        ? initialFromWalletId
        : wallets.firstWhere((w) => w.id != toWalletId, orElse: () => wallets[0]).id;
    if (fromWalletId == toWalletId) {
      toWalletId = wallets.firstWhere((w) => w.id != fromWalletId, orElse: () => wallets.last).id;
    }
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                    Text(
                      'FROM ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: wallets.map((w) {
                          final isSelected = fromWalletId == w.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  fromWalletId = w.id;
                                  if (toWalletId == w.id) {
                                    toWalletId = wallets.firstWhere((other) => other.id != w.id).id;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? palette.primary.withValues(alpha: isDark ? 0.22 : 0.15)
                                      : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? palette.primary : Colors.transparent,
                                    width: 1.3,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(w.icon, style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          w.displayName,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                        Text(
                                          '$currencySymbol${w.currentBalance.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? palette.primary : (isDark ? Colors.white38 : Colors.black38),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TO ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: wallets.where((w) => w.id != fromWalletId).map((w) {
                          final isSelected = toWalletId == w.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() => toWalletId = w.id);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGreenLight.withValues(alpha: isDark ? 0.22 : 0.15)
                                      : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryGreenLight : Colors.transparent,
                                    width: 1.3,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(w.icon, style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          w.displayName,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                        Text(
                                          '$currencySymbol${w.currentBalance.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white38 : Colors.black38),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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

  // --- Reconcile Account Dialog ---
  void _showReconcileDialog(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> wallets,
    String currencySymbol, {
    String? initialWalletId,
  }) {
    if (wallets.isEmpty) return;

    String selectedWalletId = initialWalletId != null && wallets.any((w) => w.id == initialWalletId)
        ? initialWalletId
        : wallets.first.id;
    final bankBalanceCtrl = TextEditingController();

    showBlurredDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ref.watch(activePaletteProvider);
          final currentWallet = wallets.firstWhere(
            (w) => w.id == selectedWalletId,
            orElse: () => wallets.first,
          );

          final enteredBalance = double.tryParse(bankBalanceCtrl.text.trim());
          final diff = enteredBalance != null ? enteredBalance - currentWallet.currentBalance : 0.0;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
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
                      Row(
                        children: [
                          Icon(Icons.fact_check_outlined, color: palette.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Reconcile Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Select Account Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedWalletId,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Select Account to Reconcile',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: wallets.map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.icon} ${w.displayName} ($currencySymbol${w.currentBalance.toStringAsFixed(2)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedWalletId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Calculated App Balance display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262A34) : const Color(0xFFF3F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculated App Balance',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currencySymbol ${currentWallet.currentBalance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Actual Bank Balance input
                  TextField(
                    controller: bankBalanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Actual Bank Statement Balance',
                      hintText: 'e.g. 52400.00',
                      prefixText: '$currencySymbol ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setDialogState(() {}),
                  ),

                  if (enteredBalance != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Discrepancy: ',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        Text(
                          diff == 0
                              ? 'Perfect Match ($currencySymbol 0.00)'
                              : (diff > 0
                                  ? '+$currencySymbol${diff.toStringAsFixed(2)} (App undercounted)'
                                  : '-$currencySymbol${diff.abs().toStringAsFixed(2)} (App overcounted)'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: diff == 0
                                ? AppColors.incomeGreen
                                : (diff > 0 ? AppColors.incomeGreen : AppColors.expenseRed),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newBalance = double.tryParse(bankBalanceCtrl.text.trim());
                        if (newBalance == null) {
                          TopCapsuleToast.show(context, message: 'Please enter a valid bank balance', isSuccess: false);
                          return;
                        }

                        final updatedWallet = currentWallet.copyWith(
                          initialBalance: newBalance,
                          currentBalance: newBalance,
                          balanceSnapshotAt: DateTime.now(),
                        );
                        await ref.read(walletsProvider.notifier).updateWallet(updatedWallet);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          TopCapsuleToast.show(
                            context,
                            message: '${currentWallet.name} reconciled to $currencySymbol${newBalance.toStringAsFixed(2)}',
                            isSuccess: true,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Reconcile & Update Balance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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

  Future<String?> _showSystemEmojiPicker(BuildContext context, String currentEmoji) async {
    final emojiCtrl = TextEditingController(text: currentEmoji);
    final popularEmojis = [
      '🏦', '💳', '💵', '📱', '💰', '🪙', '🏧', '📈', '🏠',
      '🚗', '🛒', '✈️', '💻', '🍔', '🍕', '⚡', '🛡️', '🎁',
      '💎', '📦', '🎓', '🏥', '🏖️', '☕', '🎟️', '🚲', '⛽',
    ];

    return showBlurredDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final palette = ProviderScope.containerOf(context).read(activePaletteProvider);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Account Emoji', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Pick from below or type ANY emoji with your keyboard:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: emojiCtrl,
                  style: const TextStyle(fontSize: 26),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Enter emoji',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: popularEmojis.map((e) {
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, e),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282B34) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final text = emojiCtrl.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.pop(ctx, text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Use Emoji', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _showCustomColorPicker(BuildContext context, int currentColor) async {
    int selected = currentColor;
    final customOptions = [
      0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1, 0xFF3949AB,
      0xFF1E88E5, 0xFF039BE5, 0xFF00ACC1, 0xFF00897B, 0xFF43A047,
      0xFF7CB342, 0xFFC0CA33, 0xFFFDD835, 0xFFFFB300, 0xFFFB8C00,
      0xFFF4511E, 0xFF6D4C41, 0xFF757575, 0xFF546E7A, 0xFF263238,
    ];

    return showBlurredDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = ProviderScope.containerOf(context).read(activePaletteProvider);

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Custom Account Color', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Pick a custom color tint for this account card', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Color(selected),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(selected).withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: customOptions.map((c) {
                      final isSel = selected == c;
                      return InkWell(
                        onTap: () => setPickerState(() => selected = c),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                          ),
                          child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Color', style: TextStyle(fontWeight: FontWeight.w700)),
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

  // ==========================================
  // --- LOANS & DEBT SECTION ---
  // ==========================================

  Widget _buildLoansSection(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> loanWallets,
    List<TransactionModel> allTxs,
    UserSettingsModel settings,
    AppThemePalette palette,
    bool isDark,
  ) {
    final totalLoanDebt = loanWallets.fold(0.0, (sum, w) => sum + w.currentBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Loans Header / Summary Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1708) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.withValues(alpha: isDark ? 0.4 : 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: isDark ? 0.1 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('📜', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'LOAN & DEBT PORTFOLIO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${loanWallets.length} Active Loans',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Outstanding Due',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isBalanceVisible ? settings.formatCurrency(totalLoanDebt) : '••••••••',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddWalletDialog(context, ref, settings.currencySymbol, initialType: WalletType.loan),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                    label: const Text(
                      '+ Add Loan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Isolated from liquid cash to avoid distorting available spend balance. Track dues, EMIs, and repayments with ease.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Loan Cards
        if (loanWallets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  'No Active Loans Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bank loan accounts (IndusInd Gold Loan, HDBFS, personal/vehicle loans) detected from SMS will automatically appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showAddWalletDialog(context, ref, settings.currencySymbol, initialType: WalletType.loan),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.amber),
                  label: const Text('Add Loan Manually', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amber)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        else
          ...loanWallets.map((loan) {
            final loanTxs = allTxs.where((tx) => tx.walletId == loan.id).take(3).toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF191C24) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Institution Icon + Name + Number + Loan Badge + More Menu
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          loan.icon.isNotEmpty ? loan.icon : '📜',
                          style: const TextStyle(fontSize: 22),
                        ),
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
                                    loan.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.35), width: 0.8),
                                  ),
                                  child: const Text(
                                    'LOAN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.amber,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loan.accountNumber != null && loan.accountNumber!.isNotEmpty
                                  ? 'A/c •••• ${loan.accountNumber}'
                                  : 'Loan Account',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white60 : Colors.black54),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showEditWalletModal(context, ref, loan, settings.currencySymbol);
                          } else if (val == 'delete') {
                            _confirmDeleteWallet(context, ref, loan);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit Loan Details')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Loan Account', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 12),

                  // Middle Row: Overdue Balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT OUTSTANDING DUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isBalanceVisible ? settings.formatCurrency(loan.currentBalance) : '••••••••',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                      // Pay EMI Button
                      ElevatedButton.icon(
                        onPressed: () {
                          final regularWallets = ref.read(walletsProvider).where((w) => w.type != WalletType.loan).toList();
                          _showTransferDialog(
                            context,
                            ref,
                            ref.read(walletsProvider),
                            settings.currencySymbol,
                            initialFromWalletId: regularWallets.isNotEmpty ? regularWallets.first.id : null,
                            initialToWalletId: loan.id,
                          );
                        },
                        icon: const Icon(Icons.payment_rounded, size: 15, color: Colors.black),
                        label: const Text(
                          'Pay EMI / Settle',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  // Recent Loan Activity snippet
                  if (loanTxs.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Recent Loan Activity',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...loanTxs.map((tx) {
                      final isCredit = tx.type == TransactionType.income;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  size: 13,
                                  color: isCredit ? AppColors.incomeGreen : AppColors.expenseRed,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tx.title.isNotEmpty ? tx.title : 'Payment',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${isCredit ? '-' : '+'}${settings.formatCurrency(tx.amount)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isCredit ? AppColors.incomeGreen : AppColors.expenseRed,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // --- OPTION 1: THE VAULT EXECUTIVE CARD ---
  // ==========================================

  Widget _buildVaultExecutiveCard({
    required BuildContext context,
    required WidgetRef ref,
    required double totalBalance,
    required List<WalletModel> wallets,
    required UserSettingsModel settings,
    required AppThemePalette palette,
    required bool isDark,
    required WalletModel? activeWallet,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13161F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF1A202E) : Colors.white,
            isDark ? const Color(0xFF10131B) : const Color(0xFFF7F9FC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Eyebrow: Total Net Worth & Account Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primary,
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOTAL NET BALANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${wallets.length} Accounts Active',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero Currency Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _isBalanceVisible ? settings.formatCurrency(totalBalance) : '••••••••',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                icon: Icon(
                  _isBalanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 22,
                ),
                tooltip: _isBalanceVisible ? 'Hide Balance' : 'Show Balance',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Actions Row: [⇄ Transfer] & [+ Add Account]
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showTransferDialog(
                    context,
                    ref,
                    wallets,
                    settings.currencySymbol,
                    initialFromWalletId: activeWallet?.id,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 18, color: palette.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Transfer',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _showAddWalletDialog(context, ref, settings.currencySymbol),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add Account',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- ENHANCED WALLET DECK & QUICK DOCK ---
  // ==========================================

  Widget _buildAccountStack(
    BuildContext context,
    List<WalletModel> wallets,
    int activeIndex,
    UserSettingsModel settings,
    AppThemePalette palette,
    bool isDark,
  ) {
    if (wallets.isEmpty) {
      return _buildEmptyAccountsCard(context, settings, palette, isDark);
    }

    final activeWallet = wallets[activeIndex];

    final List<int> peekIndices = [];
    if (wallets.length >= 3) {
      peekIndices.add((activeIndex + 2) % wallets.length);
      peekIndices.add((activeIndex + 1) % wallets.length);
    } else if (wallets.length == 2) {
      peekIndices.add((activeIndex + 1) % wallets.length);
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && wallets.length > 1) {
          if (details.primaryVelocity! < -60) {
            setState(() {
              _selectedAccountIndex = (activeIndex + 1) % wallets.length;
            });
          } else if (details.primaryVelocity! > 60) {
            setState(() {
              _selectedAccountIndex = (activeIndex - 1 + wallets.length) % wallets.length;
            });
          }
        }
      },
      child: Column(
        children: [
          SizedBox(
            height: wallets.length > 1 ? 236 : 198,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                for (var i = 0; i < peekIndices.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final peekIndex = peekIndices[i];
                      final peekWallet = wallets[peekIndex];
                      final topOffset = peekIndices.length == 2 ? (i == 0 ? 0.0 : 16.0) : 14.0;
                      final scale = peekIndices.length == 2 ? (i == 0 ? 0.91 : 0.955) : 0.95;
                      final opacity = peekIndices.length == 2 ? (i == 0 ? 0.76 : 0.88) : 0.85;

                      return Positioned(
                        top: topOffset,
                        left: 0,
                        right: 0,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topCenter,
                          child: Opacity(
                            opacity: opacity,
                            child: _buildAccountCard(
                              wallet: peekWallet,
                              isActive: false,
                              settings: settings,
                              palette: palette,
                              isDark: isDark,
                              onTap: () {
                                setState(() {
                                  _selectedAccountIndex = peekIndex;
                                });
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                Positioned(
                  top: wallets.length > 1 ? (peekIndices.length == 2 ? 32.0 : 28.0) : 0.0,
                  left: 0,
                  right: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildAccountCard(
                        wallet: activeWallet,
                        isActive: true,
                        settings: settings,
                        palette: palette,
                        isDark: isDark,
                        onTap: () => _showEditWalletModal(context, ref, activeWallet, settings.currencySymbol),
                      ),
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showAddWalletDialog(context, ref, settings.currencySymbol),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F1115) : const Color(0xFF1E232F),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Add Account',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (wallets.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < wallets.length; i++) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selectedAccountIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == activeIndex ? 18 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == activeIndex
                            ? palette.primary
                            : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  '${activeIndex + 1} of ${wallets.length} Accounts',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required WalletModel wallet,
    required bool isActive,
    required UserSettingsModel settings,
    required AppThemePalette palette,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    String networkBadge = 'BANK';
    IconData networkIcon = Icons.account_balance_rounded;

    switch (wallet.walletType) {
      case WalletType.creditCard:
        networkBadge = 'VISA';
        networkIcon = Icons.credit_card_rounded;
        break;
      case WalletType.upi:
        networkBadge = 'UPI';
        networkIcon = Icons.qr_code_rounded;
        break;
      case WalletType.bank:
        networkBadge = 'BANK';
        networkIcon = Icons.account_balance_rounded;
        break;
      case WalletType.cash:
        networkBadge = 'CASH';
        networkIcon = Icons.payments_rounded;
        break;
      case WalletType.savings:
        networkBadge = 'SAVINGS';
        networkIcon = Icons.savings_rounded;
        break;
      case WalletType.loan:
        networkBadge = 'LOAN';
        networkIcon = Icons.receipt_long_rounded;
        break;
    }

    String accountTypeLabel = 'Bank Account';
    switch (wallet.walletType) {
      case WalletType.creditCard:
        accountTypeLabel = 'Credit Card';
        break;
      case WalletType.upi:
        accountTypeLabel = 'UPI Account';
        break;
      case WalletType.bank:
        accountTypeLabel = 'Bank Account';
        break;
      case WalletType.cash:
        accountTypeLabel = 'Cash Wallet';
        break;
      case WalletType.savings:
        accountTypeLabel = 'Savings Account';
        break;
      case WalletType.loan:
        accountTypeLabel = 'Loan Account';
        break;
    }

    final cardLast4 = wallet.accountNumber != null && wallet.accountNumber!.trim().isNotEmpty
        ? (wallet.accountNumber!.length >= 4
            ? wallet.accountNumber!.substring(wallet.accountNumber!.length - 4)
            : wallet.accountNumber!)
        : '2026';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 195,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13161F) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? wallet.color.withValues(alpha: isDark ? 0.6 : 0.5)
                : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
            width: isActive ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? wallet.color : Colors.black).withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: isActive ? 22 : 12,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF1E2430) : Colors.white,
              isDark ? const Color(0xFF13161F) : const Color(0xFFF3F6FA),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: wallet.color.withValues(alpha: isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: wallet.color.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(wallet.icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              wallet.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  '•••• •••• $cardLast4',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isBalanceVisible ? settings.formatCurrency(wallet.currentBalance) : '••••••••',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Type',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(networkIcon, size: 14, color: wallet.color),
                        const SizedBox(width: 5),
                        Text(
                          accountTypeLabel,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (wallet.isDefault)
                  Container(
                    margin: const EdgeInsets.only(right: 115),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PRIMARY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAccountsCard(
    BuildContext context,
    UserSettingsModel settings,
    AppThemePalette palette,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_rounded, size: 36, color: palette.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'No Accounts Created Yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your bank accounts, credit cards, or cash wallets to track balances and transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add First Account', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showAddWalletDialog(context, ref, settings.currencySymbol),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionDock({
    required BuildContext context,
    required WidgetRef ref,
    required WalletModel? activeWallet,
    required List<WalletModel> wallets,
    required UserSettingsModel settings,
    required AppThemePalette palette,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151820) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.06),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockActionButton(
            label: 'Send',
            icon: Icons.north_east_rounded,
            color: isDark ? Colors.white : Colors.black87,
            bgColor: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF1F3F7),
            onTap: () {
              if (wallets.isEmpty) {
                TopCapsuleToast.show(context, message: 'Add an account first', isSuccess: false);
                return;
              }
              _showTransferDialog(
                context,
                ref,
                wallets,
                settings.currencySymbol,
                initialFromWalletId: activeWallet?.id,
              );
            },
            isDark: isDark,
          ),
          _buildDockActionButton(
            label: 'Request',
            icon: Icons.south_west_rounded,
            color: isDark ? Colors.white : Colors.black87,
            bgColor: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF1F3F7),
            onTap: () {
              if (activeWallet == null) return;
              _showReceiveModal(context, ref, activeWallet, settings);
            },
            isDark: isDark,
          ),
          _buildDockActionButton(
            label: 'TopUp',
            icon: Icons.credit_card_rounded,
            color: isDark ? Colors.white : Colors.black87,
            bgColor: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF1F3F7),
            onTap: () {
              if (activeWallet == null) return;
              _showTopUpModal(context, ref, activeWallet, settings.currencySymbol);
            },
            isDark: isDark,
          ),
          _buildDockActionButton(
            label: 'More',
            icon: Icons.grid_view_rounded,
            color: isDark ? Colors.white : Colors.black87,
            bgColor: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF1F3F7),
            onTap: () {
              if (activeWallet == null) return;
              _showAccountMoreActionsSheet(context, ref, activeWallet, settings, wallets);
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDockActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActivitySection(
    BuildContext context,
    WidgetRef ref,
    WalletModel? activeWallet,
    List<TransactionModel> allTxs,
    AppThemePalette palette,
    bool isDark,
  ) {
    if (activeWallet == null) return const SizedBox.shrink();

    final accountTxs = allTxs.where((t) => t.walletId == activeWallet.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: activeWallet.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(activeWallet.icon, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${activeWallet.displayName} Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            if (accountTxs.isNotEmpty)
              InkWell(
                onTap: () => context.push('/transactions'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 15, color: palette.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (accountTxs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151820) : const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 32,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 8),
                Text(
                  'No transactions on this account yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < accountTxs.take(4).length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                TransactionTile(transaction: accountTxs[i]),
              ],
            ],
          ),
      ],
    );
  }

  void _showTopUpModal(
    BuildContext context,
    WidgetRef ref,
    WalletModel wallet,
    String currencySymbol,
  ) {
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
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161A22) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.incomeGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_card_rounded, color: AppColors.incomeGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top Up Account',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              wallet.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Deposit Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      prefixText: '$currencySymbol ',
                      prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                      ),
                      hintText: '0.00',
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [500, 1000, 2000, 5000].map((quickAmt) {
                      return ActionChip(
                        label: Text('+$currencySymbol$quickAmt'),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: () {
                          final current = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                          amountCtrl.text = (current + quickAmt).toStringAsFixed(0);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Note / Reference (Optional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Salary, ATM deposit, Cash transfer',
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.incomeGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final val = double.tryParse(amountCtrl.text.trim());
                        if (val == null || val <= 0) {
                          TopCapsuleToast.show(context, message: 'Please enter a valid amount', isSuccess: false);
                          return;
                        }
                        final note = noteCtrl.text.trim();
                        await ref.read(transactionsProvider.notifier).addTransaction(
                          title: note.isNotEmpty ? note : 'Top Up ${wallet.displayName}',
                          amount: val,
                          type: TransactionType.income,
                          categoryId: 'cat_income_salary',
                          walletId: wallet.id,
                          date: DateTime.now(),
                          note: note.isNotEmpty ? note : 'Direct account top up',
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          TopCapsuleToast.show(
                            context,
                            message: 'Deposited $currencySymbol${val.toStringAsFixed(2)} to ${wallet.displayName}',
                            isSuccess: true,
                          );
                        }
                      },
                      child: const Text('Confirm Top Up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

  void _showReceiveModal(
    BuildContext context,
    WidgetRef ref,
    WalletModel wallet,
    UserSettingsModel settings,
  ) {
    showBlurredDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final palette = ref.watch(activePaletteProvider);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161A22) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.infoBlue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.south_west_rounded, color: AppColors.infoBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Receive Funds',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 90, color: Colors.grey.shade900),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                wallet.displayName,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        wallet.displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (wallet.accountNumber != null && wallet.accountNumber!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'A/C: ${wallet.maskedAccountNumber}',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: wallet.accountNumber!));
                                TopCapsuleToast.show(context, message: 'Account details copied!', isSuccess: true);
                              },
                              child: Icon(Icons.copy_rounded, size: 15, color: palette.primary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.handshake_outlined, size: 17),
                        label: const Text('Collect Debt'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/debts');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Copy Details'),
                        onPressed: () {
                          final details = '${wallet.displayName}\nBalance: ${settings.formatCurrency(wallet.currentBalance)}${wallet.accountNumber != null ? "\nAccount: " + wallet.accountNumber! : ""}';
                          Clipboard.setData(ClipboardData(text: details));
                          Navigator.pop(ctx);
                          TopCapsuleToast.show(context, message: 'Account information copied to clipboard', isSuccess: true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccountMoreActionsSheet(
    BuildContext context,
    WidgetRef ref,
    WalletModel wallet,
    UserSettingsModel settings,
    List<WalletModel> wallets,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final palette = ref.watch(activePaletteProvider);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: wallet.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(wallet.icon, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.displayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            settings.formatCurrency(wallet.currentBalance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.fact_check_outlined, color: palette.primary),
                title: const Text('Reconcile Account Balance', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Compare and adjust balance with bank statement'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReconcileDialog(context, ref, wallets, settings.currencySymbol, initialWalletId: wallet.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.infoBlue),
                title: const Text('Edit Account Details', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Rename, change color, emoji, or account number'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditWalletModal(context, ref, wallet, settings.currencySymbol);
                },
              ),
              ListTile(
                leading: Icon(wallet.isDefault ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
                title: Text(wallet.isDefault ? 'Primary Account (Default)' : 'Set as Primary Account', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(wallet.isDefault ? 'Currently used for default transactions' : 'Use this account as default for payments'),
                onTap: () async {
                  await ref.read(walletsProvider.notifier).setDefaultWallet(wallet.id);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    TopCapsuleToast.show(context, message: '${wallet.displayName} set as primary account', isSuccess: true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryGreenLight),
                title: const Text('Transfer to Another Account', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Move funds between your accounts'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTransferDialog(context, ref, wallets, settings.currencySymbol, initialFromWalletId: wallet.id);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

}
