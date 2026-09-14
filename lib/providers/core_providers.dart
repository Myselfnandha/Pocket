import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../services/auto_import_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main()');
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BackupService(storage);
});

final autoImportServiceProvider = Provider<AutoImportService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AutoImportService(storage);
});
