import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../providers/app_providers.dart';
import '../services/nlp_parser_service.dart';
import '../services/learning_suggest_service.dart';
import '../theme/app_theme.dart';

class NlpQuickAddModal extends ConsumerStatefulWidget {
  const NlpQuickAddModal({super.key});

  @override
  ConsumerState<NlpQuickAddModal> createState() => _NlpQuickAddModalState();
}

class _NlpQuickAddModalState extends ConsumerState<NlpQuickAddModal> {
  final TextEditingController _textCtrl = TextEditingController();
  ParsedNlpTransaction? _parsed;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) {
      setState(() => _parsed = null);
      return;
    }

    final categories = ref.read(categoriesProvider);
    final wallets = ref.read(walletsProvider);
    final pastTxs = ref.read(transactionsProvider);

    final parsed = NlpTransactionParser.parse(
      text,
      categories: categories,
      wallets: wallets,
      pastTxs: pastTxs,
    );

    setState(() => _parsed = parsed);
  }

  Future<void> _commitParsedTransaction() async {
    if (_parsed == null || _parsed!.amount == null || _parsed!.amount! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mention an amount (e.g. "1200 for dinner")'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final categories = ref.read(categoriesProvider);
    final wallets = ref.read(walletsProvider);

    final catId = _parsed!.categoryId ?? categories.first.id;
    final wId = _parsed!.walletId ?? (wallets.isNotEmpty ? wallets.first.id : 'default');
    final title = _parsed!.title ?? 'Transaction';

    // 1. Add transaction
    await ref.read(transactionsProvider.notifier).addTransaction(
          title: title,
          amount: _parsed!.amount!,
          type: _parsed!.type,
          categoryId: catId,
          walletId: wId,
          date: _parsed!.date,
        );

    // 2. Record learned merchant correction
    await LearningSuggestService.recordCorrection(
      merchantTitle: title,
      categoryId: catId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    final settings = ref.read(settingsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E1E1E),
        content: Text('Added $title (${settings.currencySymbol}${_parsed!.amount!.toStringAsFixed(0)}) ✓'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final parsed = _parsed;
    final category = parsed?.categoryId != null
        ? categories.firstWhere(
            (c) => c.id == parsed!.categoryId,
            orElse: () => categories.first,
          )
        : null;

    final wallet = parsed?.walletId != null
        ? wallets.where((w) => w.id == parsed!.walletId).firstOrNull ?? wallets.firstOrNull
        : wallets.firstOrNull;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryGreenLight, size: 22),
              SizedBox(width: 8),
              Text(
                'Natural Language Entry',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Natural Language Input Field
          TextField(
            controller: _textCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. "1200 for dinner with friends yesterday" or "paid 4500 wifi bill"',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: _textCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _textCtrl.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),

          // Live Parsed Tokens Preview
          if (parsed != null && (parsed.amount != null || parsed.title != null)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242424) : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Extracted Details',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight),
                      ),
                      Text(
                        '${(parsed.confidence * 100).toInt()}% match',
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (parsed.amount != null)
                        _buildTokenChip(
                          icon: Icons.attach_money_rounded,
                          label: '${settings.currencySymbol}${parsed.amount!.toStringAsFixed(0)}',
                          color: parsed.type == TransactionType.income ? AppColors.incomeGreen : AppColors.expenseRed,
                        ),
                      if (parsed.title != null && parsed.title!.isNotEmpty)
                        _buildTokenChip(
                          icon: Icons.title_rounded,
                          label: parsed.title!,
                          color: AppColors.primaryGreenLight,
                        ),
                      if (category != null)
                        _buildTokenChip(
                          icon: Icons.category_outlined,
                          label: '${category.icon} ${category.name}',
                          color: category.color,
                        ),
                      _buildTokenChip(
                        icon: Icons.calendar_today_rounded,
                        label: DateFormat('d MMM yyyy').format(parsed.date),
                        color: AppColors.infoBlue,
                      ),
                      if (wallet != null)
                        _buildTokenChip(
                          icon: Icons.account_balance_wallet_outlined,
                          label: '${wallet.icon} ${wallet.name}',
                          color: AppColors.accentOrange,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Suggestion Examples
          if (_textCtrl.text.isEmpty) ...[
            const Text(
              'Quick examples:',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                '1200 for dinner yesterday',
                'paid 850 electricity bill',
                '50000 salary from company',
                '250 for starbucks coffee',
              ].map((ex) {
                return ActionChip(
                  label: Text(ex, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _textCtrl.text = ex;
                    _textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: ex.length));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Add Transaction Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreenLight,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Add Transaction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              onPressed: _commitParsedTransaction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
