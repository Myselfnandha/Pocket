import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  late TransactionType _type;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late String _selectedCategoryId;
  late String _selectedWalletId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _type = widget.transaction.type;
    _titleController = TextEditingController(text: widget.transaction.title);
    _amountController =
        TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _selectedCategoryId = widget.transaction.categoryId;
    _selectedWalletId = widget.transaction.walletId;
    _selectedDate = widget.transaction.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final updatedTx = widget.transaction.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'Untitled'
          : _titleController.text.trim(),
      amount: amount,
      type: _type,
      categoryId: _selectedCategoryId,
      walletId: _selectedWalletId,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);

    if (!mounted) return;
    context.pop(updatedTx);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated "${updatedTx.title}" ✓'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredCategories = categories.where((c) => c.type == _type).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primaryGreenLight,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Type Selector
            Center(
              child: SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_downward_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_upward_rounded, size: 16),
                  ),
                ],
                selected: {_type},
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _type == TransactionType.expense
                      ? AppColors.expenseRed.withValues(alpha: 0.2)
                      : AppColors.incomeGreen.withValues(alpha: 0.2),
                  selectedForegroundColor: _type == TransactionType.expense
                      ? AppColors.expenseRed
                      : AppColors.incomeGreen,
                ),
                onSelectionChanged: (val) {
                  setState(() {
                    _type = val.first;
                    final cats = categories.where((c) => c.type == _type).toList();
                    if (cats.isNotEmpty && !cats.any((c) => c.id == _selectedCategoryId)) {
                      _selectedCategoryId = cats.first.id;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input
            Text(
              'Amount (${settings.currencySymbol})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '${settings.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 20),

            // Title Input
            const Text(
              'Title',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'e.g. Starbucks, Electricity Bill',
              ),
            ),
            const SizedBox(height: 20),

            // Category Selector Chips
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredCategories.map((cat) {
                final isSelected = _selectedCategoryId == cat.id;
                return ChoiceChip(
                  avatar: Text(cat.icon),
                  label: Text(cat.name),
                  selected: isSelected,
                  selectedColor: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                  onSelected: (_) {
                    setState(() => _selectedCategoryId = cat.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Wallet Selector
            const Text(
              'Wallet / Account',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wallets.map((w) {
                final isSelected = _selectedWalletId == w.id;
                return ChoiceChip(
                  avatar: Text(w.icon),
                  label: Text(w.name),
                  selected: isSelected,
                  selectedColor: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                  onSelected: (_) {
                    setState(() => _selectedWalletId = w.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Date Picker
            const Text(
              'Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryGreenLight),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Note Input
            const Text(
              'Note (Optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add additional details or remarks...',
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
