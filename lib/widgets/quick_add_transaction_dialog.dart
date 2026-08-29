import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class QuickAddTransactionDialog extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final double? initialAmount;
  final String? initialTitle;
  final String? initialCategoryId;
  final String? initialWalletId;
  final String? initialReceiptImagePath;
  final String? initialNote;
  final bool autoFocusNote;

  const QuickAddTransactionDialog({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialAmount,
    this.initialTitle,
    this.initialCategoryId,
    this.initialWalletId,
    this.initialReceiptImagePath,
    this.initialNote,
    this.autoFocusNote = false,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
    double? initialAmount,
    String? initialTitle,
    String? initialCategoryId,
    String? initialWalletId,
    String? initialReceiptImagePath,
    String? initialNote,
    bool autoFocusNote = false,
  }) {
    return showDialog(
      context: context,
      builder: (context) => QuickAddTransactionDialog(
        initialType: initialType,
        initialAmount: initialAmount,
        initialTitle: initialTitle,
        initialCategoryId: initialCategoryId,
        initialWalletId: initialWalletId,
        initialReceiptImagePath: initialReceiptImagePath,
        initialNote: initialNote,
        autoFocusNote: autoFocusNote,
      ),
    );
  }

  @override
  ConsumerState<QuickAddTransactionDialog> createState() => _QuickAddTransactionDialogState();
}

class _QuickAddTransactionDialogState extends ConsumerState<QuickAddTransactionDialog> {
  late TransactionType _type;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();

  String? _selectedCategoryId;
  String? _selectedWalletId;
  String? _receiptImagePath;
  final DateTime _selectedDate = DateTime.now();

  final List<double> _quickAmounts = [50, 100, 200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount! % 1 == 0
          ? widget.initialAmount!.toInt().toString()
          : widget.initialAmount!.toStringAsFixed(2);
    }
    if (widget.initialNote != null) {
      _notesController.text = widget.initialNote!;
    }

    _selectedCategoryId = widget.initialCategoryId;
    _selectedWalletId = widget.initialWalletId;
    _receiptImagePath = widget.initialReceiptImagePath;

    _titleController.addListener(_onTitleChanged);

    if (widget.autoFocusNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notesFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    final title = _titleController.text.trim();
    if (title.length >= 2) {
      final storage = ref.read(storageServiceProvider);
      final pastTxs = ref.read(transactionsProvider);
      final categories = ref.read(categoriesProvider);
      final matchedCatId = storage.suggestCategoryForTitle(title, pastTxs, categories);
      if (matchedCatId != null && matchedCatId != _selectedCategoryId) {
        setState(() {
          _selectedCategoryId = matchedCatId;
        });
      }
    }
  }

  void _addQuickAmount(double amt) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final total = current + amt;
    setState(() {
      _amountController.text = total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(2);
    });
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _receiptImagePath = picked.path;
      });
    }
  }

  Future<void> _quickSave() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: AppColors.expenseRed,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final categories = ref.read(categoriesProvider).where((c) => c.type == _type).toList();
    final wallets = ref.read(walletsWithBalancesProvider);

    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a wallet first'),
          backgroundColor: AppColors.expenseRed,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final defaultCatId = _type == TransactionType.expense
        ? (categories.any((c) => c.id == 'food') ? 'food' : categories.first.id)
        : (categories.any((c) => c.id == 'salary') ? 'salary' : categories.first.id);

    final catId = _selectedCategoryId ?? defaultCatId;
    final walletId = _selectedWalletId ?? wallets.first.id;
    final title = _titleController.text.trim().isEmpty ? 'Quick ${_type.name.capitalize()}' : _titleController.text.trim();
    final note = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;

    await ref.read(transactionsProvider.notifier).addTransaction(
          title: title,
          amount: amount,
          type: _type,
          categoryId: catId,
          walletId: walletId,
          date: _selectedDate,
          note: note,
          receiptImagePath: _receiptImagePath,
        );

    if (!mounted) return;
    Navigator.of(context).pop();

    final settings = ref.read(settingsProvider);
    final currencySymbol = settings.currencySymbol;
    final currencyFormat = NumberFormat('#,##0.00');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$title" • $currencySymbol${currencyFormat.format(amount)} ✓'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final currencySymbol = settings.currencySymbol;
    final currencyFormat = NumberFormat('#,##0.00');
    final allCategories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);

    // Filter categories based on transaction type
    final categories = allCategories.where((c) => c.type == _type).toList();

    if (_selectedWalletId == null && wallets.isNotEmpty) {
      _selectedWalletId = wallets.first.id;
    }
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    final categoryBudgets = ref.watch(categoryBudgetsProvider);

    // Check category budget cap
    final currentAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final activeBudgetModel = _type == TransactionType.expense && _selectedCategoryId != null
        ? categoryBudgets.where((b) => b.categoryId == _selectedCategoryId).firstOrNull
        : null;
    final activeBudget = activeBudgetModel?.monthlyLimit;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF161616) : Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.primaryGreenLight, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                _receiptImagePath != null ? 'UPI Transaction' : 'Quick Transaction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attached Screenshot Preview Chip (if shared from UPI app)
            if (_receiptImagePath != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: File(_receiptImagePath!).existsSync()
                          ? Image.file(
                              File(_receiptImagePath!),
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.receipt_long_rounded, color: AppColors.primaryGreenLight),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UPI Screenshot Attached',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight),
                          ),
                          Text(
                            'Auto-scanned receipt attached to record',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.expenseRed),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _receiptImagePath = null),
                    ),
                  ],
                ),
              ),
            ],

            // Segmented Pill Toggle: Expense vs Income
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _type = TransactionType.expense;
                          _selectedCategoryId = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.expense ? AppColors.expenseRed.withValues(alpha: 0.22) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == TransactionType.expense ? AppColors.expenseRed : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '- Expense',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _type == TransactionType.expense ? FontWeight.w800 : FontWeight.w600,
                            color: _type == TransactionType.expense
                                ? AppColors.expenseRed
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _type = TransactionType.income;
                          _selectedCategoryId = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.income ? AppColors.incomeGreen.withValues(alpha: 0.22) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == TransactionType.income ? AppColors.incomeGreen : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ Income',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _type == TransactionType.income ? FontWeight.w800 : FontWeight.w600,
                            color: _type == TransactionType.income
                                ? AppColors.incomeGreen
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Amount Input Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen,
              ),
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                prefixStyle: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen,
                ),
                hintText: '0.00',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Amount Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickAmounts.map((amt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('+$currencySymbol${amt.toInt()}'),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _addQuickAmount(amt),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Title / Merchant Input Field
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Merchant / Description (e.g. Zomato, Salary)',
                prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // Category Selector Chips
            Text(
              'SELECT CATEGORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (_type == TransactionType.expense
                                  ? AppColors.expenseRed.withValues(alpha: 0.18)
                                  : AppColors.incomeGreen.withValues(alpha: 0.18))
                              : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F2)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? (_type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(cat.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (_type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen)
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
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

            // Wallet Selector Dropdown
            Text(
              'PAYMENT WALLET',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedWalletId,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: wallets.map((w) {
                return DropdownMenuItem(
                  value: w.id,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${w.icon} ${w.name}'),
                      Text(
                        '$currencySymbol${currencyFormat.format(w.currentBalance)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: w.currentBalance >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedWalletId = val);
              },
            ),
            const SizedBox(height: 12),

            // Notes / Description & Document Attach Section
            TextField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Add description, notes, or tags (optional)...',
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.attach_file_rounded, size: 20, color: AppColors.primaryGreenLight),
                  tooltip: 'Attach Receipt / Bill',
                  onPressed: _pickReceipt,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            // Category budget warning if applicable
            if (activeBudget != null && activeBudget > 0 && currentAmount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pie_chart_rounded, size: 14, color: AppColors.accentOrange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Category Monthly Budget: $currencySymbol${currencyFormat.format(activeBudget)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/add-transaction');
              },
              icon: const Icon(Icons.open_in_full_rounded, size: 14),
              label: const Text('More Details', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: _quickSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: _type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quick Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

extension _StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
