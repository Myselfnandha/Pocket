import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';
import 'transactions_provider.dart';

class WalletsNotifier extends StateNotifier<List<WalletModel>> {
  final StorageService _storage;

  WalletsNotifier(this._storage) : super(_storage.getWallets());

  Future<void> addWallet(WalletModel wallet) async {
    state = [...state, wallet];
    await _storage.saveWallets(state);
  }

  Future<void> updateWallet(WalletModel wallet) async {
    state = [
      for (final w in state)
        if (w.id == wallet.id) wallet else w,
    ];
    await _storage.saveWallets(state);
  }

  Future<void> deleteWallet(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _storage.saveWallets(state);
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

  return wallets.map((wallet) {
    double balance = wallet.initialBalance;
    for (final tx in txs) {
      if (tx.walletId == wallet.id) {
        if (tx.type == TransactionType.income) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }
    }
    return wallet.copyWith(currentBalance: balance);
  }).toList();
});
