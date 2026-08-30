import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';

class CategoriesNotifier extends StateNotifier<List<CategoryModel>> {
  final StorageService _storage;

  CategoriesNotifier(this._storage) : super(_storage.getCategories());

  Future<void> addCategory(CategoryModel category) async {
    state = [...state, category];
    await _storage.saveCategories(state);
  }

  Future<void> updateCategory(CategoryModel category) async {
    state = [
      for (final cat in state)
        if (cat.id == category.id) category else cat,
    ];
    await _storage.saveCategories(state);
  }

  Future<void> deleteCategory(String id) async {
    state = state.where((cat) => cat.id != id).toList();
    await _storage.saveCategories(state);
  }

  Future<void> refreshFromDisk() async {
    await _storage.reload();
    state = _storage.getCategories();
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<CategoryModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return CategoriesNotifier(storage);
});
