import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main()');
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BackupService(storage);
});
