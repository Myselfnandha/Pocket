import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category_model.dart';
import '../models/detected_transaction_model.dart';
import '../providers/app_providers.dart';
import '../services/upi_detection_service.dart';
import '../theme/app_theme.dart';

class TransactionReviewModal extends ConsumerStatefulWidget {
  final DetectedTransactionModel detected;

  const TransactionReviewModal({
    super.key,
    required this.detected,
  });

  static Future<bool?> show(
    BuildContext context,
    DetectedTransactionModel detected,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TransactionReviewModal(detected: detected),
    );
  }

  @override
  ConsumerState<TransactionReviewModal> createState() => _TransactionReviewModalState();
}

class _TransactionReviewModalState extends ConsumerState<TransactionReviewModal> {
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TransactionType _type;
  late DateTime _selectedDate;
  String? _selectedWalletId;
  String? _selectedCategoryId;
  String? _receiptImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.detected.type;
    _selectedDate = widget.detected.timestamp;

    final formattedAmt = widget.detected.amount % 1.0 == 0.0
        ? widget.detected.amount.toInt().toString()
        : widget.detected.amount.toStringAsFixed(2);
    _amountController = TextEditingController(text: formattedAmt);
    _titleController = TextEditingController(text: widget.detected.merchant);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _getAppBrandColor(String appName) {
    final app = appName.toLowerCase();
    if (app.contains('google') || app.contains('gpay')) return const Color(0xFF4285F4);
    if (app.contains('phonepe')) return const Color(0xFF5F259F);
    if (app.contains('paytm')) return const Color(0xFF002E6E);
    if (app.contains('cred')) return const Color(0xFF000000);
    if (app.contains('bhim')) return const Color(0xFF00897B);
    if (app.contains('amazon')) return const Color(0xFFFF9900);
    if (app.contains('hdfc')) return const Color(0xFF004C8F);
    if (app.contains('sbi')) return const Color(0xFF280071);
    if (app.contains('icici')) return const Color(0xFFB3282D);
    if (app.contains('axis')) return const Color(0xFF97144D);
    if (app.contains('kotak')) return const Color(0xFFE21B22);
    return AppColors.primaryGreenLight;
  }

  IconData _getAppIcon(String appName) {
    final app = appName.toLowerCase();
    if (app.contains('card') || app.contains('cred')) return Icons.credit_card_rounded;
    if (app.contains('bank') || app.contains('sbi') || app.contains('hdfc') || app.contains('icici')) {
      return Icons.account_balance_rounded;
    }
    return Icons.account_balance_wallet_rounded;
  }

  Future<void> _pickReceiptImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _receiptImagePath = picked.path;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), duration: Duration(seconds: 4)),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a merchant / title'), duration: Duration(seconds: 4)),
      );
      return;
    }

    final wallets = ref.read(walletsProvider);
    final categories = ref.read(categoriesProvider);

    final walletId = _selectedWalletId ??
        (UpiDetectionService.matchWalletForApp(widget.detected.sourceApp, wallets)?.id ??
            (wallets.isNotEmpty ? wallets.first.id : ''));

    final filteredCats = categories.where((c) => c.type == _type).toList();
    final categoryId = _selectedCategoryId ??
        (UpiDetectionService.predictCategoryForMerchant(title, filteredCats)?.id ??
            (filteredCats.isNotEmpty ? filteredCats.first.id : (categories.isNotEmpty ? categories.first.id : '')));

    if (walletId.isEmpty || categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure at least 1 wallet and category exist'), duration: Duration(seconds: 4)),
      );
      return;
    }

    setState(() => _isSaving = true);

    final notesText = _notesController.text.trim();
    final fullNotes = notesText.isNotEmpty
        ? '$notesText (via ${widget.detected.sourceApp})'
        : 'Auto-detected via ${widget.detected.sourceApp}';

    // Commit transaction
    await ref.read(transactionsProvider.notifier).addTransaction(
      title: title,
      amount: amount,
      type: _type,
      categoryId: categoryId,
      walletId: walletId,
      date: _selectedDate,
      note: fullNotes,
      receiptImagePath: _receiptImagePath,
    );

    // Remove from pending queue
    await ref.read(pendingDetectedTransactionsProvider.notifier).remove(widget.detected.id);

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Saved ${widget.detected.sourceApp} transaction: $title'),
          backgroundColor: AppColors.incomeGreen,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDismiss() async {
    await ref.read(pendingDetectedTransactionsProvider.notifier).remove(widget.detected.id);
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    final wallets = ref.watch(walletsWithBalancesProvider);
    final categories = ref.watch(categoriesProvider);

    // Resolve initial pre-selections
    final matchedWallet = UpiDetectionService.matchWalletForApp(widget.detected.sourceApp, wallets);
    final activeWalletId = _selectedWalletId ?? (matchedWallet?.id ?? (wallets.isNotEmpty ? wallets.first.id : null));

    final filteredCategories = categories.where((c) => c.type == _type).toList();
    final predictedCategory = UpiDetectionService.predictCategoryForMerchant(
      _titleController.text.isNotEmpty ? _titleController.text : widget.detected.merchant,
      filteredCategories,
    );
    final activeCategoryId = _selectedCategoryId ??
        (predictedCategory?.id ?? (filteredCategories.isNotEmpty ? filteredCategories.first.id : null));

    final appColor = _getAppBrandColor(widget.detected.sourceApp);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          maxWidth: 440,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header: Source App Badge & Detection Tag
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: appColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: appColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getAppIcon(widget.detected.sourceApp), color: appColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          widget.detected.sourceApp,
                          style: TextStyle(
                            color: appColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.incomeGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.incomeGreen, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Auto-Detected',
                          style: TextStyle(
                            color: AppColors.incomeGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Type Selector (Expense / Income)
              Row(
                children: [
                  Expanded(
                    child: _buildTypeSegment(
                      title: 'Expense',
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.expenseRed,
                      isSelected: _type == TransactionType.expense,
                      onTap: () {
                        setState(() {
                          _type = TransactionType.expense;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeSegment(
                      title: 'Income',
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.incomeGreen,
                      isSelected: _type == TransactionType.income,
                      onTap: () {
                        setState(() {
                          _type = TransactionType.income;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Amount Field
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  prefixText: '$currencySymbol ',
                  prefixStyle: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen,
                  ),
                  labelText: 'Amount',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F9FA),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Merchant / Title Field
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Merchant / Recipient / Title',
                  prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F9FA),
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = null; // Re-predict category
                  });
                },
              ),
              const SizedBox(height: 14),

              // 5. Wallet Selector Dropdown
              DropdownButtonFormField<String>(
                initialValue: activeWalletId,
                decoration: InputDecoration(
                  labelText: 'Payment Wallet',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F9FA),
                ),
                items: wallets.map((w) {
                  return DropdownMenuItem<String>(
                    value: w.id,
                    child: Row(
                      children: [
                        Text(w.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        const SizedBox(width: 6),
                        Text(
                          '($currencySymbol${w.currentBalance.toStringAsFixed(2)})',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedWalletId = val);
                },
              ),
              const SizedBox(height: 14),

              // 6. Category Selection (Pills Carousel)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filteredCategories.map((c) {
                        final isSelected = c.id == activeCategoryId;
                        final catColor = Color(c.colorValue);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedCategoryId = c.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? catColor.withValues(alpha: 0.22) : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? catColor : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(c.icon, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
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
                ],
              ),
              const SizedBox(height: 14),

              // 7. Description / Remarks Input (Focused for Typing)
              TextField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Notes / Remarks (Optional)',
                  hintText: 'e.g. Lunch with team, monthly groceries...',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF7F9FA),
                ),
              ),
              const SizedBox(height: 14),

              // 8. Receipt Attachment Row
              if (_receiptImagePath != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF0F4F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_receiptImagePath!),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Receipt / Bill Attached', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Tap to remove or replace', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.expenseRed),
                        onPressed: () => setState(() => _receiptImagePath = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Attach Receipt / Bill Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: _pickReceiptImage,
                ),
                const SizedBox(height: 18),
              ],

              // 9. Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _handleDismiss,
                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreenLight,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Confirm & Save',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
