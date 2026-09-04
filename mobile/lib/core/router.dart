import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/pay_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/pay', builder: (_, __) => const PayScreen()),
    GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
    GoRoute(
      path: '/transactions/:id',
      builder: (_, state) =>
          TransactionDetailScreen(transactionId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);
