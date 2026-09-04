import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/payment_service.dart';

// ---------------------------------------------------------------------------
// Core service providers
// ---------------------------------------------------------------------------

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(ref.read(apiClientProvider)),
);

final transactionServiceProvider = Provider<TransactionService>(
  (ref) => TransactionService(ref.read(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Transaction list
// ---------------------------------------------------------------------------

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  return ref.read(transactionServiceProvider).listTransactions();
});

// ---------------------------------------------------------------------------
// Single transaction (for polling / detail view)
// ---------------------------------------------------------------------------

final transactionDetailProvider =
    FutureProvider.family<Transaction, String>((ref, id) async {
  return ref.read(transactionServiceProvider).getTransaction(id);
});

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false) {
    _load();
  }

  static const _key = 'dark_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
