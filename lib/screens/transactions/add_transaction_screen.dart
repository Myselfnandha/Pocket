import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/recurring_model.dart';
import '../../providers/app_providers.dart';
import '../../services/notification_service.dart';
import '../../services/receipt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/numpad.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialTitle;
  final TransactionType? initialType;
  final String? initialCategoryId;
  final String? initialWalletId;
  final String? initialNote;
  final String? initialReceiptImagePath;

  const AddTransactionScreen({
    super.key,
    this.initialAmount,
    this.initialTitle,
    this.initialType,
    this.initialCategoryId,
    this.initialWalletId,
    this.initialNote,
    this.initialReceiptImagePath,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  String _amountStr = '0';
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  String? _selectedCategoryId;
  String? _selectedWalletId;
  DateTime _selectedDate = DateTime.now();

  bool _showNumpad = true;
  String? _suggestedCategoryId;

  // Recurring options
  bool _isRecurring = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;

  // Receipt image
  File? _receiptFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountStr = widget.initialAmount! % 1 == 0
          ? widget.initialAmount!.toInt().toString()
          : widget.initialAmount!.toString();
    }
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId;
    }
    if (widget.initialWalletId != null) {
      _selectedWalletId = widget.initialWalletId;
    }
    if (widget.initialReceiptImagePath != null && widget.initialReceiptImagePath!.isNotEmpty) {
      final f = File(widget.initialReceiptImagePath!);
      if (f.existsSync()) {
        _receiptFile = f;
      }
    }
    _titleController.addListener(_onTitleChanged);
    _titleFocus.addListener(() {
      if (_titleFocus.hasFocus) {
        setState(() => _showNumpad = false);
      }
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    final title = _titleController.text;
    final storage = ref.read(storageServiceProvider);
    final pastTxs = ref.read(transactionsProvider);
    final categories = ref.read(categoriesProvider);

    final suggested = storage.suggestCategoryForTitle(title, pastTxs, categories);
    if (suggested != null && suggested != _suggestedCategoryId) {
      setState(() {
        _suggestedCategoryId = suggested;
        _selectedCategoryId = suggested;
      });
    }
  }

  void _handleNumpadPress(String key) {
    setState(() {
      if (_amountStr == '0') {
        if (key == '.') {
          _amountStr = '0.';
        } else if (key == '00') {
          _amountStr = '0';
        } else if (key == '+' || key == '-') {
          // Ignore operator on 0
        } else {
          _amountStr = key;
        }
      } else {
        if (key == '.' && _amountStr.contains('.')) return;
        if (_amountStr.length >= 10) return;
        _amountStr += key;
      }
    });
  }

  void _handleNumpadDelete() {
    setState(() {
      if (_amountStr.length > 1) {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      } else {
        _amountStr = '0';
      }
    });
  }

  double _parseAmount() {
    try {
      if (_amountStr.contains('+')) {
        final parts = _amountStr.split('+');
        return parts.fold(0.0, (sum, p) => sum + (double.tryParse(p.trim()) ?? 0));
      }
      if (_amountStr.contains('-')) {
        final parts = _amountStr.split('-');
        if (parts.length >= 2) {
          final first = double.tryParse(parts[0].trim()) ?? 0;
          final rest = parts.sublist(1).fold(0.0, (sum, p) => sum + (double.tryParse(p.trim()) ?? 0));
          return first - rest;
        }
      }
      return double.tryParse(_amountStr) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _saveTransaction() async {
    final amount = _parseAmount();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than 0'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final categories = ref.read(categoriesProvider);
    final wallets = ref.read(walletsProvider);

    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a wallet first in Wallets screen'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final catId = _selectedCategoryId ??
        categories
            .firstWhere(
              (c) => c.type == _type,
              orElse: () => categories.first,
            )
            .id;

    final wId = _selectedWalletId ?? wallets.first.id;
    final title = _titleController.text.trim().isEmpty
        ? categories.firstWhere((c) => c.id == catId, orElse: () => const CategoryModel(id: '', name: 'Untitled', icon: '📝', colorValue: 0)).name
        : _titleController.text.trim();

    // 1. Save Transaction with receipt path
    await ref.read(transactionsProvider.notifier).addTransaction(
          title: title,
          amount: amount,
          type: _type,
          categoryId: catId,
          walletId: wId,
          date: _selectedDate,
          receiptImagePath: _receiptFile?.path,
        );

    // 2. Save as Recurring Rule if toggled
    if (_isRecurring) {
      final now = DateTime.now();
      int dueMonth = now.month + 1;
      int dueYear = now.year;
      if (dueMonth > 12) {
        dueMonth = 1;
        dueYear++;
      }
      final nextDue = DateTime(dueYear, dueMonth, _selectedDate.day.clamp(1, 28));

      final newRule = RecurringRuleModel(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        type: _type,
        categoryId: catId,
        walletId: wId,
        frequency: _recurringFrequency,
        dueDay: _selectedDate.day.clamp(1, 28),
        nextDueDate: nextDue,
        templatePreset: RecurringTemplatePreset.custom,
        createdAt: now,
      );

      await ref.read(recurringRulesProvider.notifier).addRule(newRule);
    }

    // 3. Trigger Budget threshold checks
    final storage = ref.read(storageServiceProvider);
    final stats = ref.read(monthlyStatsProvider);
    NotificationService().checkBudgetThresholds(
      storage: storage,
      totalExpenseThisMonth: stats.totalExpense + (_type == TransactionType.expense ? amount : 0),
      totalIncomeThisMonth: stats.totalIncome + (_type == TransactionType.income ? amount : 0),
    );

    if (!mounted) return;
    context.pop();

    final settings = ref.read(settingsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$title" (${_type == TransactionType.income ? '+' : '-'}${settings.currencySymbol}${amount.toStringAsFixed(2)}) ✓'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryGreenLight,
          onPressed: () {
            final allTxs = ref.read(transactionsProvider);
            if (allTxs.isNotEmpty) {
              ref.read(transactionsProvider.notifier).deleteTransaction(allTxs.first.id);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredCategories = categories.where((c) => c.type == _type).toList();
    if (_selectedCategoryId == null && filteredCategories.isNotEmpty) {
      _selectedCategoryId = filteredCategories.first.id;
    }
    if (_selectedWalletId == null && wallets.isNotEmpty) {
      _selectedWalletId = wallets.first.id;
    }

    final selectedWallet = wallets.firstWhere(
      (w) => w.id == _selectedWalletId,
      orElse: () => wallets.isNotEmpty ? wallets.first : defaultWallets.first,
    );

    final isIncome = _type == TransactionType.income;
    final activeColor = isIncome ? AppColors.incomeGreen : AppColors.expenseRed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.primaryGreenLight, size: 28),
            onPressed: _saveTransaction,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _titleFocus.unfocus();
          setState(() => _showNumpad = true);
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Centered Segmented Type Selector
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _type = TransactionType.expense;
                                  final expCats = categories.where((c) => c.type == TransactionType.expense).toList();
                                  _selectedCategoryId = expCats.isNotEmpty ? expCats.first.id : null;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_typeIsIncome()
                                      ? AppColors.expenseRed
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.call_made_rounded,
                                      size: 16,
                                      color: !_typeIsIncome() ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Expense',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: !_typeIsIncome() ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _type = TransactionType.income;
                                  final incCats = categories.where((c) => c.type == TransactionType.income).toList();
                                  _selectedCategoryId = incCats.isNotEmpty ? incCats.first.id : null;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _typeIsIncome()
                                      ? AppColors.incomeGreen
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.call_received_rounded,
                                      size: 16,
                                      color: _typeIsIncome() ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _typeIsIncome() ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Large Amount Input Display
                    GestureDetector(
                      onTap: () {
                        _titleFocus.unfocus();
                        setState(() => _showNumpad = true);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: activeColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'AMOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${isIncome ? '+' : '-'}${settings.currencySymbol}$_amountStr',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: activeColor,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Title / Custom Tag Input
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      decoration: InputDecoration(
                        hintText: 'Enter title, custom tag, or description...',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        suffixIcon: _titleController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _titleController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3.5 Real-time Category Budget Warning Banner (If Expense & Budget Configured)
                    if (!isIncome && _selectedCategoryId != null) ...[
                      Consumer(
                        builder: (context, ref, _) {
                          final budgets = ref.watch(categoryBudgetsProvider);
                          final matchingBudget = budgets.where((b) => b.categoryId == _selectedCategoryId).firstOrNull;
                          if (matchingBudget == null) return const SizedBox.shrink();

                          final spendingMap = ref.watch(currentMonthCategorySpendingProvider);
                          final currentSpent = spendingMap[_selectedCategoryId] ?? 0.0;
                          final enteredAmount = _parseAmount();
                          final projectedTotal = currentSpent + enteredAmount;
                          final isExceeded = projectedTotal > matchingBudget.monthlyLimit;
                          final isNearLimit = projectedTotal >= (matchingBudget.monthlyLimit * 0.8) && !isExceeded;

                          final cat = categories.firstWhere(
                            (c) => c.id == _selectedCategoryId,
                            orElse: () => const CategoryModel(id: '', name: 'Category', icon: '🏷️', colorValue: 0),
                          );

                          if (!isExceeded && !isNearLimit) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.incomeGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.incomeGreen.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.incomeGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Safe budget buffer: ${settings.currencySymbol}${(matchingBudget.monthlyLimit - projectedTotal).toStringAsFixed(0)} left for ${cat.name}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.incomeGreen),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final bannerColor = isExceeded ? AppColors.expenseRed : AppColors.accentOrange;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: bannerColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: bannerColor.withValues(alpha: 0.4), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isExceeded ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                  size: 18,
                                  color: bannerColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isExceeded
                                            ? 'Exceeds ${cat.name} Monthly Budget!'
                                            : 'Nearing ${cat.name} Budget Limit (80%+)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: bannerColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isExceeded
                                            ? 'Projected ${settings.currencySymbol}${projectedTotal.toStringAsFixed(0)} exceeds limit of ${settings.currencySymbol}${matchingBudget.monthlyLimit.toStringAsFixed(0)} by ${settings.currencySymbol}${(projectedTotal - matchingBudget.monthlyLimit).toStringAsFixed(0)}'
                                            : 'Will reach ${((projectedTotal / matchingBudget.monthlyLimit) * 100).toStringAsFixed(0)}% of monthly limit (${settings.currencySymbol}${projectedTotal.toStringAsFixed(0)} / ${settings.currencySymbol}${matchingBudget.monthlyLimit.toStringAsFixed(0)})',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // 4. Categories Horizontal List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (_selectedCategoryId != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedCategoryId = null),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.primaryGreenLight)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredCategories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = filteredCategories[index];
                          final isSelected = cat.id == _selectedCategoryId;

                          return ChoiceChip(
                            avatar: Text(cat.icon, style: const TextStyle(fontSize: 13)),
                            label: Text(cat.name),
                            selected: isSelected,
                            selectedColor: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                            onSelected: (_) {
                              _titleFocus.unfocus();
                              setState(() {
                                _selectedCategoryId = isSelected ? null : cat.id;
                                _showNumpad = true;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. Account/Wallet & Date Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _titleFocus.unfocus();
                              _showWalletPicker(wallets);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(selectedWallet.icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedWallet.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _titleFocus.unfocus();
                              _pickDate();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryGreenLight),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatSelectedDate(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 6. Attach Private Receipt / Bill Photo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: _receiptFile == null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.primaryGreenLight),
                                    SizedBox(width: 8),
                                    Text('Attach Bill / Receipt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryGreenLight, size: 22),
                                      tooltip: 'Take Photo',
                                      onPressed: () => _pickReceipt(ImageSource.camera),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.photo_library_outlined, color: AppColors.primaryGreenLight, size: 22),
                                      tooltip: 'Choose Image',
                                      onPressed: () => _pickReceipt(ImageSource.gallery),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _showZoomableImage(context, _receiptFile!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(_receiptFile!, width: 48, height: 48, fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Receipt Attached ✓', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.incomeGreen)),
                                      const SizedBox(height: 2),
                                      Text('Stored privately (hidden from gallery)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: AppColors.expenseRed, size: 20),
                                  onPressed: () => setState(() => _receiptFile = null),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),

                    // 7. Make Recurring Toggle Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.autorenew_rounded, size: 20, color: AppColors.primaryGreenLight),
                                  SizedBox(width: 8),
                                  Text('Make this Recurring', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Switch(
                                value: _isRecurring,
                                activeThumbColor: AppColors.primaryGreenLight,
                                onChanged: (val) {
                                  _titleFocus.unfocus();
                                  setState(() => _isRecurring = val);
                                },
                              ),
                            ],
                          ),
                          if (_isRecurring) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Repeat Frequency:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                DropdownButton<RecurringFrequency>(
                                  value: _recurringFrequency,
                                  isDense: true,
                                  items: RecurringFrequency.values.map((f) {
                                    return DropdownMenuItem(
                                      value: f,
                                      child: Text(f.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  onChanged: (f) {
                                    if (f != null) setState(() => _recurringFrequency = f);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showNumpad)
              CalculatorNumpad(
                onKeyPress: _handleNumpadPress,
                onDelete: _handleNumpadDelete,
                onConfirm: _saveTransaction,
              ),
          ],
        ),
      ),
    );
  }

  bool _typeIsIncome() => _type == TransactionType.income;

  String _formatSelectedDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(dt);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    _titleFocus.unfocus();
    final file = await ReceiptService().pickOrCaptureReceipt(source: source);
    if (file != null) {
      setState(() => _receiptFile = file);
    }
  }

  void _showZoomableImage(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(file),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletPicker(List<WalletModel> wallets) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Wallet / Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ...wallets.map((w) {
                  final isSelected = w.id == _selectedWalletId;
                  return ListTile(
                    leading: Text(w.icon, style: const TextStyle(fontSize: 22)),
                    title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Balance: ${w.currentBalance.toStringAsFixed(2)}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedWalletId = w.id;
                        _showNumpad = true;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
