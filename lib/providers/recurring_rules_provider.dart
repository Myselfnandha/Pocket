import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recurring_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';

class RecurringRulesNotifier extends StateNotifier<List<RecurringRuleModel>> {
  final StorageService _storage;

  RecurringRulesNotifier(this._storage) : super(_storage.getRecurringRules());

  Future<void> addRule(RecurringRuleModel rule) async {
    state = [...state, rule];
    await _storage.saveRecurringRules(state);
  }

  Future<void> updateRule(RecurringRuleModel rule) async {
    state = [
      for (final r in state)
        if (r.id == rule.id) rule else r,
    ];
    await _storage.saveRecurringRules(state);
  }

  Future<void> toggleRuleActive(String id) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(isActive: !r.isActive) else r,
    ];
    await _storage.saveRecurringRules(state);
  }

  Future<void> deleteRule(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _storage.saveRecurringRules(state);
  }

  Future<int> processDueRules() async {
    final generatedCount = await _storage.processDueRecurringRules();
    if (generatedCount > 0) {
      state = _storage.getRecurringRules();
    }
    return generatedCount;
  }
}

final recurringRulesProvider =
    StateNotifierProvider<RecurringRulesNotifier, List<RecurringRuleModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecurringRulesNotifier(storage);
});
