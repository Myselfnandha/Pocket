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
import '../../services/anomaly_detection_service.dart';
import '../../services/learning_suggest_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/numpad.dart';
import '../../widgets/nlp_quick_add_modal.dart';
import '../../widgets/blurred_dialog_utils.dart';
import '../../widgets/top_capsule_toast.dart';

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

  // Tags and Multi-Attachments
  final List<String> _tags = [];
  final TextEditingController _tagCtrl = TextEditingController();
  final List<String> _additionalAttachments = [];

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
    _tagCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    final title = _titleController.text;
    final storage = ref.read(storageServiceProvider);
    final pastTxs = ref.read(transactionsProvider);
    final categories = ref.read(categoriesProvider);

    final suggested = LearningSuggestService.suggestCategory(
      title: title,
      categories: categories,
      pastTransactions: pastTxs,
    ) ?? storage.suggestCategoryForTitle(title, pastTxs, categories);

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

    final allAttachments = [
      if (_receiptFile != null) _receiptFile!.path,
      ..._additionalAttachments,
    ];

    // 1. Save Transaction with tags & attachments
    await ref.read(transactionsProvider.notifier).addTransaction(
          title: title,
          amount: amount,
          type: _type,
          categoryId: catId,
          walletId: wId,
          date: _selectedDate,
          receiptImagePath: _receiptFile?.path,
          tags: _tags,
          attachments: allAttachments,
        );

    // 1.5 Record learned merchant-to-category correction
    await LearningSuggestService.recordCorrection(
      merchantTitle: title,
      categoryId: catId,
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
    final matchedCat = categories.where((c) => c.id == catId).firstOrNull;
    TopCapsuleToast.show(
      context,
      title: title,
      amountText: '${_type == TransactionType.income ? '+' : '-'}${settings.currencySymbol}${settings.formatCurrency(amount)}',
      categoryIcon: matchedCat?.icon ?? (_type == TransactionType.income ? '💰' : '💸'),
      isSuccess: true,
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
            icon: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryGreenLight),
            tooltip: 'Natural Language Entry',
            onPressed: () => NlpQuickAddModal.show(context),
          ),
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
          FocusScope.of(context).unfocus();
          setState(() => _showNumpad = false);
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

                    // 3.4 AI Statistical Anomaly Detection Warning Banner
                    if (!isIncome && _selectedCategoryId != null) ...[
                      Consumer(
                        builder: (context, ref, _) {
                          final pastTxs = ref.watch(transactionsProvider);
                          final enteredAmt = _parseAmount();
                          final anomaly = AnomalyDetectionService.checkAnomaly(
                            amount: enteredAmt,
                            categoryId: _selectedCategoryId!,
                            pastTransactions: pastTxs,
                            categories: categories,
                            currencySymbol: settings.currencySymbol,
                          );

                          if (!anomaly.isAnomaly) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.insights_rounded,
                                  size: 18,
                                  color: AppColors.accentOrange,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Unusually Large Entry Detected (AI)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentOrange,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        anomaly.message,
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

                    // 5. Dynamic Directional Header & Rich Account Cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isIncome ? Icons.south_west_rounded : Icons.arrow_outward_rounded,
                              size: 14,
                              color: activeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isIncome ? 'DEPOSIT INTO ACCOUNT' : 'PAY FROM ACCOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: activeColor,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            _titleFocus.unfocus();
                            _pickDate();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primaryGreenLight),
                                const SizedBox(width: 5),
                                Text(
                                  _formatSelectedDate(_selectedDate),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontal Rich Account Cards Row
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: wallets.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == wallets.length) {
                            return InkWell(
                              onTap: () {
                                _titleFocus.unfocus();
                                _showWalletPicker(wallets);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.more_horiz_rounded, size: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'All',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final w = wallets[index];
                          final isSelected = w.id == _selectedWalletId;
                          return InkWell(
                            onTap: () {
                              _titleFocus.unfocus();
                              setState(() {
                                _selectedWalletId = w.id;
                                _showNumpad = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? activeColor.withValues(alpha: 0.15)
                                    : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? activeColor : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: activeColor.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(w.icon, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        w.displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected
                                              ? (isDark ? Colors.white : Colors.black87)
                                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${settings.currencySymbol}${settings.formatCurrency(w.currentBalance)}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? activeColor : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.check_circle_rounded, size: 14, color: activeColor),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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

                    // 6.5 Multi-Tags & Ad-hoc Labels Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tag_rounded, size: 18, color: AppColors.primaryGreenLight),
                                  SizedBox(width: 8),
                                  Text('Tags & Labels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              if (_tags.isNotEmpty)
                                Text('${_tags.length} added', style: const TextStyle(fontSize: 11, color: AppColors.primaryGreenLight)),
                            ],
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _tags.map((tag) {
                                return Chip(
                                  label: Text('#$tag', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => setState(() => _tags.remove(tag)),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tagCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Add tag (e.g. BusinessTrip, Tax, Vacation)',
                                    hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
                                  ),
                                  onSubmitted: (val) {
                                    final clean = val.replaceAll('#', '').trim();
                                    if (clean.isNotEmpty && !_tags.contains(clean)) {
                                      setState(() {
                                        _tags.add(clean);
                                        _tagCtrl.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
                                onPressed: () {
                                  final clean = _tagCtrl.text.replaceAll('#', '').trim();
                                  if (clean.isNotEmpty && !_tags.contains(clean)) {
                                    setState(() {
                                      _tags.add(clean);
                                      _tagCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final existingTags = ref.watch(allTagsProvider);
                              final suggestions = existingTags.where((t) => !_tags.contains(t)).take(4).toList();
                              if (suggestions.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: suggestions.map((s) {
                                    return ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('+$s', style: const TextStyle(fontSize: 11)),
                                      onPressed: () => setState(() => _tags.add(s)),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.read(settingsProvider);

    showBlurredDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryGreenLight.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
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
                    const Text(
                      'Select Wallet / Account',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...wallets.map((w) {
                  final isSelected = w.id == _selectedWalletId;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedWalletId = w.id;
                        _showNumpad = true;
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryGreenLight : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(w.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.displayName,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Balance: ${settings.currencySymbol}${settings.formatCurrency(w.currentBalance)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
