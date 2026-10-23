import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../services/storage_service.dart';
import '../services/system_widget_service.dart';
import 'core_providers.dart';
import 'transactions_provider.dart';

class WalletsNotifier extends StateNotifier<List<WalletModel>> {
  final StorageService _storage;

  WalletsNotifier(this._storage) : super(_storage.getWallets());

  Future<void> addWallet(WalletModel wallet) async {
    state = [...state, wallet];
    await _storage.saveWallets(state);
    unawaited(SystemWidgetService.syncFromStorage(_storage));
  }

  Future<void> updateWallet(WalletModel wallet) async {
    state = [
      for (final w in state)
        if (w.id == wallet.id) wallet else w,
    ];
    await _storage.saveWallets(state);
    unawaited(SystemWidgetService.syncFromStorage(_storage));
  }

  Future<void> deleteWallet(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _storage.saveWallets(state);
    unawaited(SystemWidgetService.syncFromStorage(_storage));
  }

  Future<void> setDefaultWallet(String id) async {
    state = [
      for (final w in state)
        w.copyWith(isDefault: w.id == id),
    ];
    await _storage.saveWallets(state);
    unawaited(SystemWidgetService.syncFromStorage(_storage));
  }

  Future<void> refreshFromDisk() async {
    await _storage.reload();
    state = _storage.getWallets();
  }
}

final walletsProvider =
    StateNotifierProvider<WalletsNotifier, List<WalletModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return WalletsNotifier(storage);
});

// Purely reactive wallets with real-time balance calculations
final walletsWithBalancesProvider = Provider<List<WalletModel>>((ref) {
  final wallets = ref.watch(walletsProvider);
  final txs = ref.watch(transactionsProvider);

  final primaryWallet = wallets.isNotEmpty
      ? wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first)
      : null;

  return wallets.map((wallet) {
    double balance = wallet.initialBalance;
    for (final tx in txs) {
      final matchesThisWallet = tx.walletId == wallet.id ||
          (wallet == primaryWallet &&
              (tx.walletId == 'default_cash' || !wallets.any((w) => w.id == tx.walletId)));
      if (matchesThisWallet) {
        // If this wallet has a balance snapshot timestamp, only transactions occurring AFTER
        // that snapshot should adjust the balance. Transactions dated before or at the snapshot
        // are already reflected in the snapshot initial balance.
        if (wallet.balanceSnapshotAt != null && !tx.date.isAfter(wallet.balanceSnapshotAt!)) {
          continue;
        }
        if (tx.type == TransactionType.income) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }
    }
    double rounded = (balance * 100).round() / 100.0;
    if (rounded.abs() < 0.0001) rounded = 0.0;
    return wallet.copyWith(currentBalance: rounded);
  }).toList();
});
