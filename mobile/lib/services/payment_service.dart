import '../models/transaction.dart';
import 'api_client.dart';

class PaymentService {
  final ApiClient _client;
  PaymentService(this._client);

  Future<Map<String, dynamic>> initiateStkPush({
    required String phoneNumber,
    required double amount,
    required String accountReference,
    required String description,
    String? idempotencyKey,
  }) async {
    final body = {
      'phone_number': phoneNumber,
      'amount': amount,
      'account_reference': accountReference,
      'description': description,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };
    return _client.post('/api/v1/payments/stk', body);
  }

  Future<Transaction> getPayment(String transactionId) async {
    final data = await _client.get('/api/v1/payments/$transactionId');
    return Transaction.fromJson(data);
  }

  Future<Transaction> syncPayment(String transactionId) async {
    final data = await _client.post('/api/v1/payments/$transactionId/sync', {});
    return Transaction.fromJson(data);
  }
}

class TransactionService {
  final ApiClient _client;
  TransactionService(this._client);

  Future<List<Transaction>> listTransactions({int limit = 20, int offset = 0}) async {
    final data = await _client.get('/api/v1/transactions?limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>;
    return items.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Transaction> getTransaction(String id) async {
    final data = await _client.get('/api/v1/transactions/$id');
    return Transaction.fromJson(data);
  }
}
