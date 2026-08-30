import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../providers/app_providers.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class QuickAddTransactionDialog extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final double? initialAmount;
  final String? initialTitle;
  final String? initialCategoryId;
  final String? initialWalletId;
  final String? initialReceiptImagePath;
  final String? initialNote;
  final String? initialSenderName;
  final String? initialReceiverName;
  final String? initialRefId;
  final String? initialCounterpartyLast4;
  final bool autoFocusNote;
  final bool isStandaloneScreen;

  const QuickAddTransactionDialog({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialAmount,
    this.initialTitle,
    this.initialCategoryId,
    this.initialWalletId,
    this.initialReceiptImagePath,
    this.initialNote,
    this.initialSenderName,
    this.initialReceiverName,
    this.initialRefId,
    this.initialCounterpartyLast4,
    this.autoFocusNote = false,
    this.isStandaloneScreen = false,
  });

  static bool isOpen = false;

  static Future<void> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
    double? initialAmount,
    String? initialTitle,
    String? initialCategoryId,
    String? initialWalletId,
    String? initialReceiptImagePath,
    String? initialNote,
    String? initialSenderName,
    String? initialReceiverName,
    String? initialRefId,
    String? initialCounterpartyLast4,
    bool autoFocusNote = false,
    bool isStandaloneScreen = false,
  }) async {
    if (isOpen) return;
    isOpen = true;
    try {
      await showDialog(
        context: context,
        builder: (context) => QuickAddTransactionDialog(
          initialType: initialType,
          initialAmount: initialAmount,
          initialTitle: initialTitle,
          initialCategoryId: initialCategoryId,
          initialWalletId: initialWalletId,
          initialReceiptImagePath: initialReceiptImagePath,
          initialNote: initialNote,
          initialSenderName: initialSenderName,
          initialReceiverName: initialReceiverName,
          initialRefId: initialRefId,
          initialCounterpartyLast4: initialCounterpartyLast4,
          autoFocusNote: autoFocusNote,
          isStandaloneScreen: isStandaloneScreen,
        ),
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        isOpen = false;
      });
    }
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
  String? _senderName;
  String? _receiverName;
  String? _refId;
  String? _counterpartyLast4;
  final DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

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
    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _notesController.text = widget.initialNote!;
    }

    _selectedCategoryId = widget.initialCategoryId;
    _selectedWalletId = widget.initialWalletId;
    _receiptImagePath = widget.initialReceiptImagePath;
    _senderName = widget.initialSenderName;
    _receiverName = widget.initialReceiverName;
    _refId = widget.initialRefId;
    _counterpartyLast4 = widget.initialCounterpartyLast4;

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

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _receiptImagePath = picked.path;
      });
    }
  }

  void _closeDialog() {
    if (widget.isStandaloneScreen) {
      SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _quickSave() async {
    if (_isSaving) return;

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

    setState(() => _isSaving = true);

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
          senderName: _senderName,
          receiverName: _receiverName,
          refId: _refId,
          counterpartyLast4: _counterpartyLast4,
        );

    if (!mounted) return;
    _closeDialog();

    final settings = ref.read(settingsProvider);
    final currencySymbol = settings.currencySymbol;
    final currencyFormat = NumberFormat('#,##0.00');
    final selectedWallet = wallets.firstWhere((w) => w.id == walletId, orElse: () => wallets.first);

    if (widget.isStandaloneScreen) {
      // Trigger floating Android system notification with 4-second auto-dismiss
      NotificationService().showTransactionLoggedNotification(
        title: title,
        amount: amount,
        currencySymbol: currencySymbol,
        isIncome: _type == TransactionType.income,
        walletName: selectedWallet.name,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E1E1E),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added "$title" • $currencySymbol${currencyFormat.format(amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: isDark ? const Color(0xFF161616) : Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
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
            onPressed: _closeDialog,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attached Screenshot / Receipt Preview Chip
            if (_receiptImagePath != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                            'Receipt Attached',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight),
                          ),
                          Text(
                            _refId != null && _refId!.isNotEmpty
                                ? 'Ref: $_refId'
                                : 'Attached to this transaction record',
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

            // Sender & Receiver OCR Badge (if detected)
            if (_senderName != null || _receiverName != null || _counterpartyLast4 != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222222) : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.infoBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (_senderName != null) 'From: $_senderName',
                          if (_receiverName != null) 'To: $_receiverName',
                          if (_counterpartyLast4 != null) '•••• $_counterpartyLast4',
                        ].join('  •  '),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

            // Amount Input Field with auto-focus trigger
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    autofocus: widget.initialAmount == null || widget.initialAmount == 0,
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
                ),
                const SizedBox(width: 8),
                // Camera / Receipt Attachment Icon Button
                PopupMenuButton<ImageSource>(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242424) : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _receiptImagePath != null ? AppColors.primaryGreenLight : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: _receiptImagePath != null ? AppColors.primaryGreenLight : (isDark ? Colors.white70 : Colors.black87),
                      size: 20,
                    ),
                  ),
                  tooltip: 'Attach Receipt / Bill',
                  onSelected: (source) => _pickReceipt(source),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ImageSource.camera,
                      child: Row(
                        children: [
                          Icon(Icons.photo_camera_rounded, size: 18, color: AppColors.primaryGreenLight),
                          SizedBox(width: 10),
                          Text('Take Photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ImageSource.gallery,
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_rounded, size: 18, color: AppColors.infoBlue),
                          SizedBox(width: 10),
                          Text('Choose from Gallery'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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

            // Account & Wallet Selector
            Text(
              'PAY VIA ACCOUNT',
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
                children: wallets.map((w) {
                  final isSelected = _selectedWalletId == w.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedWalletId = w.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreenLight.withValues(alpha: 0.18)
                              : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F2)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryGreenLight : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(w.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              w.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primaryGreenLight : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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

            // User Note Field (100% clean for user custom note)
            TextField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Add a note (e.g. Split with Alex)...',
                prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            if (activeBudget != null && activeBudget > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: currentAmount > activeBudget
                      ? AppColors.expenseRed.withValues(alpha: 0.12)
                      : AppColors.primaryGreenLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentAmount > activeBudget ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 14,
                      color: currentAmount > activeBudget ? AppColors.expenseRed : AppColors.primaryGreenLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Monthly Cap: $currencySymbol${currencyFormat.format(activeBudget)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: currentAmount > activeBudget ? AppColors.expenseRed : AppColors.primaryGreenLight,
                        ),
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
        if (!widget.isStandaloneScreen)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final amount = double.tryParse(_amountController.text.trim());
              context.push(
                '/add-transaction',
                extra: {
                  'type': _type,
                  'amount': amount,
                  'title': _titleController.text.trim(),
                  'categoryId': _selectedCategoryId,
                  'walletId': _selectedWalletId,
                  'note': _notesController.text.trim(),
                  'receiptImagePath': _receiptImagePath,
                  'senderName': _senderName,
                  'receiverName': _receiverName,
                  'refId': _refId,
                  'counterpartyLast4': _counterpartyLast4,
                },
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: const Text('More Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ElevatedButton(
          onPressed: _isSaving ? null : _quickSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreenLight,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'Quick Save',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
