import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vick Mpesa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications are not enabled yet.')),
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(transactionsProvider),
        child: ListView(
          children: [
            // Greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(greeting,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ),

            // Balance card
            const _BalanceCard(),

            // Quick actions
            const SectionHeader('Quick Actions'),
            const _QuickActions(),

            // Recent transactions
            const SectionHeader('Recent Transactions'),
            transactionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: LoadingView(),
              ),
              error: (e, _) => ErrorView(
                e.toString(),
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
              data: (txns) {
                if (txns.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No transactions yet.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  );
                }
                final recent = txns.take(5).toList();
                return Column(
                  children: [
                    ...recent.map((t) => TransactionTile(
                          transaction: t,
                          onTap: () => context.push('/transactions/${t.id}'),
                        )),
                    if (txns.length > 5)
                      TextButton(
                        onPressed: () => context.push('/transactions'),
                        child: const Text('View all transactions'),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatefulWidget {
  const _BalanceCard();

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('M-PESA',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Available balance',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _visible ? 'KSh ——' : 'KSh ••••••',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _visible = !_visible),
                  child: Row(
                    children: [
                      Icon(
                        _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _visible ? 'Hide' : 'Show',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Balance not available via API — requires Safaricom production onboarding',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.send_outlined, 'Send', '/pay'),
      (Icons.receipt_long_outlined, 'PayBill', '/pay'),
      (Icons.phone_android_outlined, 'Airtime', '/pay'),
      (Icons.store_outlined, 'Till', '/pay'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: actions.map((a) {
          return _ActionButton(icon: a.$1, label: a.$2, route: a.$3);
        }).toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _ActionButton({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
