import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/numpad.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

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

  String? _suggestedCategoryId;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
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
        // Auto-select suggested category if user hasn't explicitly picked one
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
        // Prevent duplicate decimals
        if (key == '.' && _amountStr.contains('.')) return;
        // Limit total length to 10 digits
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
      // Evaluate simple addition/subtraction if entered
      if (_amountStr.contains('+')) {
        final parts = _amountStr.split('+');
        return parts.fold(0.0, (sum, p) => sum + (double.tryParse(p.trim()) ?? 0));
      }
      if (_amountStr.contains('-')) {
        final parts = _amountStr.split('-');
        if (parts.length == 2) {
          final first = double.tryParse(parts[0].trim()) ?? 0;
          final second = double.tryParse(parts[1].trim()) ?? 0;
          return first - second;
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
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final categories = ref.read(categoriesProvider);
    final wallets = ref.read(walletsProvider);

    final catId = _selectedCategoryId ??
        categories
            .firstWhere(
              (c) => c.type == _type,
              orElse: () => categories.first,
            )
            .id;

    final wId = _selectedWalletId ?? wallets.first.id;
    final title = _titleController.text.trim().isEmpty
        ? categories.firstWhere((c) => c.id == catId).name
        : _titleController.text.trim();

    await ref.read(transactionsProvider.notifier).addTransaction(
          title: title,
          amount: amount,
          type: _type,
          categoryId: catId,
          walletId: wId,
          date: _selectedDate,
        );

    if (!mounted) return;
    context.pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$title" (${_type == TransactionType.income ? '+' : '-'}₹${amount.toStringAsFixed(2)}) ✓'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryGreenLight,
          onPressed: () {
            // Delete the last added transaction
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: SegmentedButton<TransactionType>(
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
          onSelectionChanged: (newSelection) {
            setState(() {
              _type = newSelection.first;
              _selectedCategoryId = null;
            });
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // Amount Display
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          settings.currencySymbol,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _amountStr,
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: _type == TransactionType.expense
                                ? (_amountStr == '0'
                                    ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
                                    : AppColors.expenseRed)
                                : (_amountStr == '0'
                                    ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
                                    : AppColors.incomeGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title Input with Category Auto-suggest
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What was this for? (e.g. Lunch at Zomato)',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Selector Chips with Auto-suggest highlight
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredCategories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = filteredCategories[index];
                          final isSelected = _selectedCategoryId == cat.id;
                          final isSuggested = _suggestedCategoryId == cat.id;

                          return FilterChip(
                            avatar: Text(cat.icon),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cat.name),
                                if (isSuggested && !isSelected) ...[
                                  const SizedBox(width: 4),
                                  const Text('✨', style: TextStyle(fontSize: 10)),
                                ],
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategoryId = cat.id;
                              });
                            },
                            selectedColor: AppColors.primaryGreenLight.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primaryGreenLight,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primaryGreenLight
                                  : (isSuggested
                                      ? AppColors.accentOrange
                                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
                              width: isSuggested ? 1.5 : 1.0,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Wallet & Date Row
                    Row(
                      children: [
                        // Wallet selector
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showWalletPicker(wallets),
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
                                  Text(
                                    wallets.firstWhere((w) => w.id == _selectedWalletId, orElse: () => wallets.first).icon,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      wallets.firstWhere((w) => w.id == _selectedWalletId, orElse: () => wallets.first).name,
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
                        const SizedBox(width: 10),

                        // Date selector
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _pickDate,
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Calculator Numpad at the bottom
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
                    subtitle: Text('Balance: ₹${w.currentBalance.toStringAsFixed(2)}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight)
                        : null,
                    onTap: () {
                      setState(() => _selectedWalletId = w.id);
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
