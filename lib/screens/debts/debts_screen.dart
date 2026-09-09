import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/debt_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../services/system_contact_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_capsule_toast.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final totalLent = ref.watch(totalLentProvider);
    final totalBorrowed = ref.watch(totalBorrowedProvider);
    final settings = ref.watch(settingsProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeDebts = debts.where((d) => !d.isSettled).toList();
    final lentDebts = debts.where((d) => !d.isSettled && d.type == DebtType.lent).toList();
    final borrowedDebts = debts.where((d) => !d.isSettled && d.type == DebtType.borrowed).toList();
    final settledDebts = debts.where((d) => d.isSettled).toList();
    final currencyFormat = NumberFormat('#,##0.00');

    final netPosition = totalLent - totalBorrowed;
    final isNetPositive = netPosition >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts & Loans'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: palette.primary),
            tooltip: 'Add Debt / Loan',
            onPressed: () => _showAddDebtModal(context, ref, wallets, settings.currencySymbol, debts),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Summary Hero with Net Position Pill & Dual Luminous Mini-Meter Metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.primary.withValues(alpha: isDark ? 0.28 : 0.2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Net Position Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isNetPositive ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isNetPositive ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isNetPositive ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                          size: 14,
                          color: isNetPositive ? AppColors.incomeGreen : AppColors.expenseRed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isNetPositive
                              ? '+${settings.currencySymbol}${currencyFormat.format(netPosition)} Net to Collect'
                              : '-${settings.currencySymbol}${currencyFormat.format(netPosition.abs())} Net to Pay',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isNetPositive ? AppColors.incomeGreen : AppColors.expenseRed,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dual Luminous Mini-Meter Metrics
                  Row(
                    children: [
                      // Lent / You are owed
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.incomeGreen.withValues(alpha: isDark ? 0.25 : 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.incomeGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.incomeGreen),
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'You are owed',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.incomeGreen),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '+${settings.currencySymbol}${currencyFormat.format(totalLent)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.incomeGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Borrowed / You owe
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.expenseRed.withValues(alpha: isDark ? 0.25 : 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.expenseRed.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.expenseRed),
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'You owe',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.expenseRed),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '-${settings.currencySymbol}${currencyFormat.format(totalBorrowed)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.expenseRed),
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
          ),

          // 2. 4 Filter Tabs: All, Lent, Borrowed, Settled
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: palette.primary,
            labelColor: palette.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            tabs: [
              Tab(text: 'All (${activeDebts.length})'),
              Tab(text: 'Lent (${lentDebts.length})'),
              Tab(text: 'Borrowed (${borrowedDebts.length})'),
              Tab(text: 'Settled (${settledDebts.length})'),
            ],
          ),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDebtsList(activeDebts, settings.currencySymbol, currencyFormat, wallets, isDark, false, 'No active debts or loans', palette),
                _buildDebtsList(lentDebts, settings.currencySymbol, currencyFormat, wallets, isDark, false, 'No money currently lent to others', palette),
                _buildDebtsList(borrowedDebts, settings.currencySymbol, currencyFormat, wallets, isDark, false, 'No money currently borrowed from others', palette),
                _buildDebtsList(settledDebts, settings.currencySymbol, currencyFormat, wallets, isDark, true, 'Fully settled debts will appear here in history', palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsList(
    List<DebtModel> list,
    String currencySymbol,
    NumberFormat currencyFormat,
    List<WalletModel> wallets,
    bool isDark,
    bool isSettledList,
    String emptyMessage,
    dynamic palette,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isSettledList ? '🎉' : '🤝', style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(
                isSettledList ? 'No Settled Debts' : 'Empty Debt Ledger',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final debt = list[index];
        final isLent = debt.type == DebtType.lent;
        final progress = debt.totalAmount > 0 ? (1 - (debt.remainingAmount / debt.totalAmount)).clamp(0.0, 1.0) : 1.0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isLent ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Prominent Type Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isLent ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 10,
                                color: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isLent ? 'LENT • YOU GAVE' : 'BORROWED • YOU TOOK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isLent ? '+' : '-'}$currencySymbol${currencyFormat.format(debt.remainingAmount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                        ),
                      ),
                      Text(
                        'Total: $currencySymbol${currencyFormat.format(debt.totalAmount)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress Bar with Percentage Badge
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0),
                        valueColor: AlwaysStoppedAnimation<Color>(isLent ? AppColors.incomeGreen : AppColors.expenseRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isLent ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(progress * 100).toInt()}% settled',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (debt.dueDate != null) ...[
                        const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accentOrange),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${DateFormat('d MMM yyyy').format(debt.dueDate!)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentOrange),
                        ),
                      ] else ...[
                        Text(
                          'Created: ${DateFormat('d MMM').format(debt.createdAt)}',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!debt.isSettled) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: const Size(0, 28),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 13),
                          label: const Text('Payment', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showPartialPaymentDialog(context, ref, debt, wallets, currencySymbol),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            minimumSize: const Size(0, 28),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 13),
                          label: const Text('Settle Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showSettleUpDialog(context, ref, debt, wallets, currencySymbol),
                        ),
                      ],
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expenseRed),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => ref.read(debtsProvider.notifier).deleteDebt(debt.id),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDebtModal(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> wallets,
    String currencySymbol,
    List<DebtModel> existingDebts,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DebtType selectedType = DebtType.lent;
    DateTime? selectedDueDate;
    String selectedWalletId = wallets.isNotEmpty ? wallets.first.id : 'cash';
    bool updateWalletBalance = true;

    final existingNames = existingDebts.map((d) => d.personName).toSet().toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Debt / Loan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-width edge-to-edge segmented toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFEBEBEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedType = DebtType.lent),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedType == DebtType.lent
                                  ? AppColors.incomeGreen.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedType == DebtType.lent
                                    ? AppColors.incomeGreen
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: selectedType == DebtType.lent
                                        ? AppColors.incomeGreen
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lent (Gave)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: selectedType == DebtType.lent
                                          ? AppColors.incomeGreen
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedType = DebtType.borrowed),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedType == DebtType.borrowed
                                  ? AppColors.expenseRed.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedType == DebtType.borrowed
                                    ? AppColors.expenseRed
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 14,
                                    color: selectedType == DebtType.borrowed
                                        ? AppColors.expenseRed
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Borrowed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: selectedType == DebtType.borrowed
                                          ? AppColors.expenseRed
                                          : Colors.grey,
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
                const SizedBox(height: 14),

                // Existing person autocompletion chips
                if (existingNames.isNotEmpty) ...[
                  const Text('Recent Contacts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: existingNames.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          label: Text(existingNames[i], style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            nameCtrl.text = existingNames[i];
                            final past = existingDebts.firstWhere((d) => d.personName == existingNames[i]);
                            if (past.phoneNumber != null) phoneCtrl.text = past.phoneNumber!;
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Person Name',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts_rounded, size: 20),
                      tooltip: 'Pick from Contacts',
                      onPressed: () async {
                        final contact = await SystemContactService.pickContact();
                        if (contact != null) {
                          setDialogState(() {
                            nameCtrl.text = contact.name;
                            if (contact.phone != null) {
                              phoneCtrl.text = contact.phone!;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number (optional)'),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '$currencySymbol ',
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes / Reason (optional)'),
                ),
                const SizedBox(height: 8),

                // Due date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, size: 20),
                  title: Text(
                    selectedDueDate == null
                        ? 'No Due Date'
                        : 'Due: ${DateFormat('d MMM yyyy').format(selectedDueDate!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: selectedDueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setDialogState(() => selectedDueDate = null),
                        )
                      : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setDialogState(() => selectedDueDate = picked);
                  },
                ),
                const SizedBox(height: 8),

                // Wallet sync option
                Row(
                  children: [
                    Checkbox(
                      value: updateWalletBalance,
                      activeColor: AppColors.primaryGreenLight,
                      onChanged: (val) => setDialogState(() => updateWalletBalance = val ?? true),
                    ),
                    const Expanded(
                      child: Text('Update wallet balance now', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                if (updateWalletBalance) ...[
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedWalletId,
                    items: wallets.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text('${w.icon} ${w.name}'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedWalletId = val);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (name.isEmpty || amount <= 0) return;

                ref.read(debtsProvider.notifier).addDebt(
                      personName: name,
                      phoneNumber: phoneCtrl.text.trim(),
                      amount: amount,
                      type: selectedType,
                      dueDate: selectedDueDate,
                      walletId: selectedWalletId,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      updateWallet: updateWalletBalance,
                    );

                Navigator.pop(ctx);
                if (context.mounted) {
                  TopCapsuleToast.show(
                    context,
                    title: 'Debt Added',
                    subtitle: '${selectedType == DebtType.lent ? "Lent to" : "Borrowed from"} $name • $currencySymbol$amount',
                    accentColor: selectedType == DebtType.lent ? AppColors.incomeGreen : AppColors.expenseRed,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPartialPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    DebtModel debt,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedWalletId = wallets.isNotEmpty ? wallets.first.id : 'cash';
    bool updateWallet = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add Payment for ${debt.personName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remaining: $currencySymbol${debt.remainingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(prefixText: '$currencySymbol ', hintText: 'Payment Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(hintText: 'Note (optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: updateWallet,
                    activeColor: AppColors.primaryGreenLight,
                    onChanged: (val) => setDialogState(() => updateWallet = val ?? true),
                  ),
                  const Expanded(
                    child: Text('Update wallet balance', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amt <= 0) return;

                ref.read(debtsProvider.notifier).recordPayment(
                      debtId: debt.id,
                      amount: amt,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      walletId: selectedWalletId,
                      updateWallet: updateWallet,
                    );

                Navigator.pop(ctx);
                if (context.mounted) {
                  TopCapsuleToast.show(
                    context,
                    title: 'Payment Recorded',
                    subtitle: '$currencySymbol${amt.toStringAsFixed(2)} for ${debt.personName}',
                    accentColor: AppColors.incomeGreen,
                  );
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleUpDialog(
    BuildContext context,
    WidgetRef ref,
    DebtModel debt,
    List<WalletModel> wallets,
    String currencySymbol,
  ) {
    String selectedWalletId = wallets.isNotEmpty ? wallets.first.id : 'cash';
    bool updateWallet = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Settle Up Completely?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark full remaining balance ($currencySymbol${debt.remainingAmount.toStringAsFixed(2)}) as paid?'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Checkbox(
                    value: updateWallet,
                    activeColor: AppColors.primaryGreenLight,
                    onChanged: (val) => setDialogState(() => updateWallet = val ?? true),
                  ),
                  const Expanded(
                    child: Text('Update wallet balance', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(debtsProvider.notifier).settleDebt(
                      debtId: debt.id,
                      walletId: selectedWalletId,
                      updateWallet: updateWallet,
                    );
                Navigator.pop(ctx);
                if (context.mounted) {
                  TopCapsuleToast.show(
                    context,
                    title: 'Debt Settled',
                    subtitle: 'Settled completely with ${debt.personName}',
                    accentColor: AppColors.incomeGreen,
                  );
                }
              },
              child: const Text('Settle Up'),
            ),
          ],
        ),
      ),
    );
  }
}
