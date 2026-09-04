import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _search = '';
  TransactionStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by reference or phone...',
                prefixIcon: Icon(Icons.search_outlined),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _filter == null,
                    onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                ...TransactionStatus.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: s.name[0].toUpperCase() + s.name.substring(1),
                        selected: _filter == s,
                        onTap: () => setState(() => _filter = s),
                      ),
                    )),
              ],
            ),
          ),

          // List
          Expanded(
            child: txnsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(e.toString(),
                  onRetry: () => ref.invalidate(transactionsProvider)),
              data: (txns) {
                final filtered = txns.where((t) {
                  final matchesFilter = _filter == null || t.status == _filter;
                  final matchesSearch = _search.isEmpty ||
                      t.accountReference.toLowerCase().contains(_search) ||
                      t.phoneNumber.contains(_search);
                  return matchesFilter && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No transactions found.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transactionsProvider),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) => TransactionTile(
                      transaction: filtered[i],
                      onTap: () => context.push('/transactions/${filtered[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
