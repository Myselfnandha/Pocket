import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/transaction_tile.dart';

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  String _searchQuery = '';
  TransactionType? _typeFilter;
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final allTxs = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter transactions
    final filtered = allTxs.where((tx) {
      // Type filter
      if (_typeFilter != null && tx.type != _typeFilter) return false;

      // Category filter
      if (_categoryFilter != null && tx.categoryId != _categoryFilter) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = tx.title.toLowerCase().contains(query);
        final matchesNote = tx.note?.toLowerCase().contains(query) ?? false;
        final cat = categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => const CategoryModel(
            id: '',
            name: '',
            icon: '',
            colorValue: 0,
          ),
        );
        final matchesCategory = cat.name.toLowerCase().contains(query);
        if (!matchesTitle && !matchesNote && !matchesCategory) return false;
      }

      return true;
    }).toList();

    // Group by formatted date
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in filtered) {
      final key = _formatDateHeader(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: AppColors.primaryGreenLight,
            tooltip: 'Add Transaction',
            onPressed: () => context.push('/add-transaction'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search by title, note, or category...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // 2. Filter Chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _typeFilter == null && _categoryFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _typeFilter = null;
                      _categoryFilter = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expense'),
                  selected: _typeFilter == TransactionType.expense,
                  onSelected: (_) {
                    setState(() {
                      _typeFilter = _typeFilter == TransactionType.expense
                          ? null
                          : TransactionType.expense;
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Income'),
                  selected: _typeFilter == TransactionType.income,
                  onSelected: (_) {
                    setState(() {
                      _typeFilter = _typeFilter == TransactionType.income
                          ? null
                          : TransactionType.income;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...categories.take(6).map((cat) {
                  final isSel = _categoryFilter == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Text(cat.icon, style: const TextStyle(fontSize: 12)),
                      label: Text(cat.name),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() {
                          _categoryFilter = isSel ? null : cat.id;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Transactions List
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try clearing filters or search query',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, sectionIndex) {
                      final dateHeader = grouped.keys.elementAt(sectionIndex);
                      final items = grouped[dateHeader]!;

                      // Calculate day total
                      double dayExpense = 0;
                      for (final item in items) {
                        if (item.type == TransactionType.expense) {
                          dayExpense += item.amount;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Section Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateHeader,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreenLight,
                                  ),
                                ),
                                if (dayExpense > 0)
                                  Text(
                                    '-${settings.currencySymbol}${dayExpense.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Transaction rows
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceVariant
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder,
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder,
                              ),
                              itemBuilder: (context, i) {
                                final tx = items[i];
                                return TransactionTile(
                                  transaction: tx,
                                  onTap: () => context.push(
                                    '/transaction-detail',
                                    extra: tx,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat('d MMM').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('d MMM').format(dt)}';
    }
    return DateFormat('EEEE, d MMM yyyy').format(dt);
  }
}
