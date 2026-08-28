import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import '../../models/debt_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeDebts = debts.where((d) => !d.isSettled).toList();
    final settledDebts = debts.where((d) => d.isSettled).toList();
    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts & Loans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryGreenLight),
            tooltip: 'Add Debt / Loan',
            onPressed: () => _showAddDebtModal(context, ref, wallets, settings.currencySymbol, debts),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Summary Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.incomeGreen),
                            SizedBox(width: 4),
                            Text('You are owed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.incomeGreen)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+${settings.currencySymbol}${currencyFormat.format(totalLent)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.incomeGreen),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.expenseRed),
                            SizedBox(width: 4),
                            Text('You owe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.expenseRed)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '-${settings.currencySymbol}${currencyFormat.format(totalBorrowed)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.expenseRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Tab Bar: Active vs Settled
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryGreenLight,
            labelColor: AppColors.primaryGreenLight,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            tabs: [
              Tab(text: 'Active (${activeDebts.length})'),
              Tab(text: 'Settled (${settledDebts.length})'),
            ],
          ),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDebtsList(activeDebts, settings.currencySymbol, currencyFormat, wallets, isDark, false),
                _buildDebtsList(settledDebts, settings.currencySymbol, currencyFormat, wallets, isDark, true),
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
                isSettledList ? 'No Settled Debts' : 'No Active Debts or Loans',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSettledList
                    ? 'Fully paid debts will appear here in history'
                    : 'Track money given to or borrowed from friends and colleagues',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final debt = list[index];
        final isLent = debt.type == DebtType.lent;
        final progress = debt.totalAmount > 0 ? (1 - (debt.remainingAmount / debt.totalAmount)).clamp(0.0, 1.0) : 1.0;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isLent ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (debt.phoneNumber != null && debt.phoneNumber!.isNotEmpty)
                          Text(
                            debt.phoneNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
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
                          fontSize: 16,
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
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(isLent ? AppColors.incomeGreen : AppColors.expenseRed),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (debt.dueDate != null) ...[
                        Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accentOrange),
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
                    children: [
                      if (!debt.isSettled) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _showPartialPaymentDialog(context, ref, debt, wallets, currencySymbol),
                          child: const Text('Add Payment', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isLent ? AppColors.incomeGreen : AppColors.expenseRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _showSettleUpDialog(context, ref, debt, wallets, currencySymbol),
                          child: const Text('Settle Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expenseRed),
                        visualDensity: VisualDensity.compact,
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
                // Type selector
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Lent (You gave)'),
                      selected: selectedType == DebtType.lent,
                      selectedColor: AppColors.incomeGreen.withValues(alpha: 0.25),
                      onSelected: (_) => setDialogState(() => selectedType = DebtType.lent),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Borrowed (You took)'),
                      selected: selectedType == DebtType.borrowed,
                      selectedColor: AppColors.expenseRed.withValues(alpha: 0.25),
                      onSelected: (_) => setDialogState(() => selectedType = DebtType.borrowed),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Contact Name & Contact Picker Button
                Row(
                  children: [
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder: (textVal) {
                          if (textVal.text.isEmpty) return const [];
                          return existingNames.where((n) => n.toLowerCase().contains(textVal.text.toLowerCase()));
                        },
                        onSelected: (selection) => nameCtrl.text = selection,
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          nameCtrl.addListener(() {
                            if (textEditingController.text != nameCtrl.text) {
                              textEditingController.text = nameCtrl.text;
                            }
                          });
                          textEditingController.addListener(() {
                            nameCtrl.text = textEditingController.text;
                          });
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(hintText: 'Person Name *', prefixIcon: Icon(Icons.person_outline_rounded)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.contacts_rounded, color: AppColors.primaryGreenLight),
                      tooltip: 'Pick from Phone Contacts',
                      onPressed: () async {
                        try {
                          final hasPermission = await FlutterContacts.requestPermission();
                          if (hasPermission) {
                            final contact = await FlutterContacts.openExternalPick();
                            if (contact != null) {
                              setDialogState(() {
                                nameCtrl.text = contact.displayName;
                                if (contact.phones.isNotEmpty) {
                                  phoneCtrl.text = contact.phones.first.number;
                                }
                              });
                            }
                          }
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Phone number
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Phone Number (optional)', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(prefixText: '$currencySymbol ', hintText: 'Total Amount *'),
                ),
                const SizedBox(height: 12),

                // Due Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primaryGreenLight),
                  title: Text(
                    selectedDueDate == null ? 'Set Due Date (optional)' : 'Due: ${DateFormat('d MMM yyyy').format(selectedDueDate!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: selectedDueDate != null
                      ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setDialogState(() => selectedDueDate = null))
                      : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
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
              },
              child: const Text('Settle Up'),
            ),
          ],
        ),
      ),
    );
  }
}
