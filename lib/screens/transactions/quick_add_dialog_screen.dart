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
  UpiParsedTransaction? _sharedTx;

  @override
  void initState() {
    super.initState();
    QuickAddTransactionDialog.isOpen = true;
    _checkSharedPayload();
  }

  Future<void> _checkSharedPayload() async {
    try {
      const channel = MethodChannel('com.pocket.pocket/shared_transaction');
      final payload = await channel.invokeMethod<String>('getPendingSharedTransaction');
      if (payload != null && payload.isNotEmpty) {
        final parsed = UpiParsedTransaction.fromPayloadString(payload);
        if (mounted) {
          setState(() {
            _sharedTx = parsed;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
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
                child: QuickAddTransactionDialog(
                  isStandaloneScreen: true,
                  initialType: _sharedTx?.isIncome == true ? TransactionType.income : TransactionType.expense,
                  initialAmount: _sharedTx?.amount,
                  initialTitle: _sharedTx?.merchant,
                  initialCategoryId: _sharedTx?.suggestedCategoryId,
                  initialReceiptImagePath: _sharedTx?.imagePath,
                  initialSenderName: _sharedTx?.senderName,
                  initialReceiverName: _sharedTx?.receiverName,
                  initialRefId: _sharedTx?.refId,
                  initialCounterpartyLast4: _sharedTx?.counterpartyLast4,
                  initialNote: null, // Note field remains completely clean for user
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
