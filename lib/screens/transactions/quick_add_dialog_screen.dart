import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/quick_add_transaction_dialog.dart';

class QuickAddDialogScreen extends StatefulWidget {
  const QuickAddDialogScreen({super.key});

  @override
  State<QuickAddDialogScreen> createState() => _QuickAddDialogScreenState();
}

class _QuickAddDialogScreenState extends State<QuickAddDialogScreen> {
  @override
  void initState() {
    super.initState();
    QuickAddTransactionDialog.isOpen = true;
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
                child: const QuickAddTransactionDialog(
                  isStandaloneScreen: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
