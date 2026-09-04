enum TransactionStatus {
  created,
  initiated,
  pending,
  success,
  failed,
  cancelled,
  timeout,
  unknown;

  static TransactionStatus fromString(String s) {
    return TransactionStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == s.toUpperCase(),
      orElse: () => TransactionStatus.unknown,
    );
  }

  bool get isTerminal =>
      this == success || this == failed || this == cancelled || this == timeout;

  bool get isPending =>
      this == created || this == initiated || this == pending;
}

enum TransactionType {
  stkPush,
  c2b,
  b2c,
  b2b;

  static TransactionType fromString(String s) {
    const map = {
      'STK_PUSH': TransactionType.stkPush,
      'C2B': TransactionType.c2b,
      'B2C': TransactionType.b2c,
      'B2B': TransactionType.b2b,
    };
    return map[s.toUpperCase()] ?? TransactionType.stkPush;
  }

  String get displayName {
    switch (this) {
      case stkPush: return 'Payment';
      case c2b: return 'Received';
      case b2c: return 'Sent';
      case b2b: return 'Business';
    }
  }
}

class Transaction {
  final String id;
  final String clientReference;
  final String? providerReference;
  final String phoneNumber;
  final double amount;
  final String currency;
  final TransactionType type;
  final TransactionStatus status;
  final String accountReference;
  final String description;
  final String? providerResponseDescription;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const Transaction({
    required this.id,
    required this.clientReference,
    this.providerReference,
    required this.phoneNumber,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.accountReference,
    required this.description,
    this.providerResponseDescription,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      clientReference: json['client_reference'] as String,
      providerReference: json['provider_reference'] as String?,
      phoneNumber: json['phone_number'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'KES',
      type: TransactionType.fromString(json['transaction_type'] as String),
      status: TransactionStatus.fromString(json['status'] as String),
      accountReference: json['account_reference'] as String,
      description: json['description'] as String,
      providerResponseDescription: json['provider_response_description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
