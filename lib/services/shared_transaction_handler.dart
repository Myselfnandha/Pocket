import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'upi_screenshot_parser_service.dart';

class SharedTransactionHandler {
  static const MethodChannel _channel = MethodChannel('com.pocket.pocket/shared_transaction');
  static Function(UpiParsedTransaction data)? _listener;

  /// Initializes the shared transaction listener on app startup
  static void initialize({required Function(UpiParsedTransaction data) onTransactionReceived}) {
    _listener = onTransactionReceived;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedTransactionReceived') {
        final payload = call.arguments as String?;
        if (payload != null && payload.isNotEmpty) {
          final parsed = UpiParsedTransaction.fromPayloadString(payload);
          _listener?.call(parsed);
        }
      }
    });

    // Check for cold-start pending transaction
    _checkPendingSharedTransaction();
  }

  static Future<void> _checkPendingSharedTransaction() async {
    try {
      final payload = await _channel.invokeMethod<String>('getPendingSharedTransaction');
      if (payload != null && payload.isNotEmpty) {
        final parsed = UpiParsedTransaction.fromPayloadString(payload);
        _listener?.call(parsed);
      }
    } catch (e) {
      debugPrint('Error checking pending shared transaction: $e');
    }
  }

  static void dispose() {
    _listener = null;
  }
}
