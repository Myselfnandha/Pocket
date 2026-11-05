// Copyright (c) 2026 Pocket Project. All rights reserved.
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/services/auto_import_service.dart';

void main() async {
  // #region scan_and_drain
  // Initialize offline storage engine and the auto-import coordinator
  final storage = await StorageService.init();
  final autoImport = AutoImportService(storage);

  // Scan device SMS inbox for bank transactions within the last 7 days
  final pendingTransactions = await autoImport.scanSmsInbox(daysLookback: 7);

  // ignore: avoid_print
  print('Discovered ${pendingTransactions.length} pending transactions.');
  // #endregion scan_and_drain
}
