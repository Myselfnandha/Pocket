import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';

class NotificationsNotifier extends StateNotifier<List<AppNotificationModel>> {
  final StorageService _storage;

  NotificationsNotifier(this._storage) : super(_storage.getNotifications());

  Future<void> addNotification(AppNotificationModel notif) async {
    state = [notif, ...state];
    await _storage.saveNotifications(state);
  }

  Future<void> markAsRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    await _storage.saveNotifications(state);
  }

  Future<void> markAllAsRead() async {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    await _storage.saveNotifications(state);
  }

  Future<void> clearAll() async {
    state = [];
    await _storage.saveNotifications([]);
  }

  Future<void> refreshFromDisk() async {
    await _storage.reload();
    state = _storage.getNotifications();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotificationModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationsNotifier(storage);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.where((n) => !n.isRead).length;
});
