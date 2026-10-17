import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pending_transaction_model.dart';
import '../models/transaction_model.dart';
import '../providers/core_providers.dart';
import '../services/auto_import_service.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';

class SmsInboxScannerSheet extends ConsumerStatefulWidget {
  const SmsInboxScannerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SmsInboxScannerSheet(),
    );
  }

  @override
  ConsumerState<SmsInboxScannerSheet> createState() => _SmsInboxScannerSheetState();
}

class _SmsInboxScannerSheetState extends ConsumerState<SmsInboxScannerSheet> {
  int _selectedDaysLookback = 30;
  bool _isScanning = false;
  bool _hasScanned = false;
  List<PendingTransactionModel> _scannedTransactions = [];
  final Set<String> _selectedIds = {};
  bool _isImporting = false;

  final List<Map<String, dynamic>> _lookbackOptions = [
    {'label': '7 Days', 'days': 7},
    {'label': '30 Days', 'days': 30},
    {'label': '90 Days', 'days': 90},
    {'label': 'All Time', 'days': 0},
  ];

  @override
  void initState() {
    super.initState();
    // Auto start scan on open with default 30 days
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _hasScanned = false;
      _scannedTransactions = [];
      _selectedIds.clear();
    });

    final autoImportService = ref.read(autoImportServiceProvider);
    
    // First ensure permission is granted
    final permissions = await autoImportService.checkPermissions();
    if (!permissions.isSmsListenerEnabled) {
      final granted = await autoImportService.requestSmsPermission();
      if (!granted && mounted) {
        setState(() {
          _isScanning = false;
          _hasScanned = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission is required to scan your inbox'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
        return;
      }
    }

    final results = await autoImportService.scanSmsInbox(daysLookback: _selectedDaysLookback);

    if (mounted) {
      setState(() {
        _isScanning = false;
        _hasScanned = true;
        _scannedTransactions = results;
        _selectedIds.addAll(results.map((e) => e.id));
      });
    }
  }

  Future<void> _importSelected() async {
    if (_selectedIds.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    final selectedItems = _scannedTransactions.where((e) => _selectedIds.contains(e.id)).toList();
    final wallets = ref.read(walletsProvider);
    final fallbackWalletId = wallets.isNotEmpty
        ? (wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first).id)
        : 'cash';

    int importedCount = 0;
    for (final item in selectedItems) {
      final effectiveWalletId = (item.suggestedWalletId != null && wallets.any((w) => w.id == item.suggestedWalletId))
          ? item.suggestedWalletId!
          : fallbackWalletId;
      final effectiveCategoryId = item.suggestedCategoryId ?? 'food';
      final effectiveNote = item.refId != null && item.refId!.isNotEmpty
          ? 'Ref: ${item.refId}'
          : (item.appSource.isNotEmpty ? 'Imported via ${item.appSource}' : null);

      await ref.read(transactionsProvider.notifier).addTransaction(
        title: item.merchant,
        amount: item.amount,
        type: item.isIncome ? TransactionType.income : TransactionType.expense,
        categoryId: effectiveCategoryId,
        walletId: effectiveWalletId,
        date: item.date,
        note: effectiveNote,
        refId: item.refId,
      );
      importedCount++;
    }

    if (mounted) {
      setState(() {
        _isImporting = false;
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $importedCount SMS transactions!'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = ref.watch(activePaletteProvider);
    final settings = ref.watch(settingsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.sms_rounded, color: palette.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan SMS Inbox',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Auto-discover bank debits and credits',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Time range filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: _lookbackOptions.map((opt) {
                final isSelected = _selectedDaysLookback == opt['days'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: palette.primary,
                    backgroundColor: isDark ? const Color(0xFF22222E) : Colors.grey.shade100,
                    showCheckmark: false,
                    onSelected: (val) {
                      if (val && !_isScanning) {
                        setState(() {
                          _selectedDaysLookback = opt['days'] as int;
                        });
                        _startScan();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 16),

          // Content body
          Expanded(
            child: _isScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: palette.primary),
                        const SizedBox(height: 18),
                        const Text(
                          'Scanning SMS inbox for bank transactions...',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Filtering financial debits, UPI transfers & salary credits',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : !_hasScanned
                    ? const SizedBox.shrink()
                    : _scannedTransactions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade500),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No New Transactions Found',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'All bank SMS in this timeframe are already logged or no transaction messages were detected.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Try All Time Scan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: palette.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedDaysLookback = 0;
                                      });
                                      _startScan();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Selection sub-header
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_scannedTransactions.length} Transactions Found',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_selectedIds.length == _scannedTransactions.length) {
                                            _selectedIds.clear();
                                          } else {
                                            _selectedIds.addAll(_scannedTransactions.map((e) => e.id));
                                          }
                                        });
                                      },
                                      child: Text(
                                        _selectedIds.length == _scannedTransactions.length ? 'Deselect All' : 'Select All',
                                        style: TextStyle(color: palette.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // List of transactions
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  itemCount: _scannedTransactions.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, index) {
                                    final tx = _scannedTransactions[index];
                                    final isSelected = _selectedIds.contains(tx.id);
                                    final isIncome = tx.isIncome;
                                    final amountColor = isIncome ? const Color(0xFF00E676) : const Color(0xFFFF5252);

                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedIds.remove(tx.id);
                                          } else {
                                            _selectedIds.add(tx.id);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E28) : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: isSelected
                                                ? palette.primary.withValues(alpha: 0.6)
                                                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor: palette.primary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedIds.add(tx.id);
                                                  } else {
                                                    _selectedIds.remove(tx.id);
                                                  }
                                                });
                                              },
                                            ),
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: amountColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                                                color: amountColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tx.merchant,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        DateFormat('dd MMM, hh:mm a').format(tx.date),
                                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                      ),
                                                      if (tx.counterpartyLast4 != null) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '•••• ${tx.counterpartyLast4}',
                                                            style: TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${isIncome ? '+' : '-'}${settings.currencySymbol}${tx.amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                                color: amountColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),

          // Bottom Action Bar
          if (_hasScanned && _scannedTransactions.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _selectedIds.isEmpty || _isImporting ? null : _importSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isImporting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Import ${_selectedIds.length} Transactions',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
