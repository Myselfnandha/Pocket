import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/category_model.dart';
import '../../services/upi_screenshot_parser_service.dart';
import '../../widgets/quick_add_transaction_dialog.dart';

class QuickAddDialogScreen extends StatefulWidget {
  const QuickAddDialogScreen({super.key});

  @override
  State<QuickAddDialogScreen> createState() => _QuickAddDialogScreenState();
}

class _QuickAddDialogScreenState extends State<QuickAddDialogScreen> {
  static const _channel = MethodChannel('com.pocket.pocket/shared_transaction');
  UpiParsedTransaction? _sharedTx;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    QuickAddTransactionDialog.isOpen = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedTransactionReceived') {
        final payload = call.arguments as String?;
        if (payload != null && payload.isNotEmpty) {
          final parsed = UpiParsedTransaction.fromPayloadString(payload);
          if (mounted) {
            setState(() {
              _sharedTx = parsed;
              _isLoading = false;
            });
          }
        }
      }
    });

    _checkSharedPayload();
  }

  Future<void> _checkSharedPayload() async {
    try {
      final payload = await _channel.invokeMethod<String>('getPendingSharedTransaction');
      if (payload != null && payload.isNotEmpty) {
        final parsed = UpiParsedTransaction.fromPayloadString(payload);
        if (mounted) {
          setState(() {
            _sharedTx = parsed;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    QuickAddTransactionDialog.isOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            SystemNavigator.pop();
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: () {}, // Prevent taps on dialog from closing
                child: _isLoading
                    ? Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5),
                            SizedBox(height: 16),
                            Text(
                              'Loading transaction details...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : QuickAddTransactionDialog(
                        isStandaloneScreen: true,
                        transactionIdToUpdate: _sharedTx?.id,
                        initialType: _sharedTx?.isIncome == true ? TransactionType.income : TransactionType.expense,
                        initialAmount: _sharedTx?.amount,
                        initialTitle: _sharedTx?.merchant,
                        initialCategoryId: _sharedTx?.suggestedCategoryId,
                        initialReceiptImagePath: _sharedTx?.imagePath,
                        initialSenderName: _sharedTx?.senderName,
                        initialReceiverName: _sharedTx?.receiverName,
                        initialRefId: _sharedTx?.refId,
                        initialCounterpartyLast4: _sharedTx?.counterpartyLast4,
                        initialNote: null,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
