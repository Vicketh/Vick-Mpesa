import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vick_mpesa/models/transaction.dart';
import 'package:vick_mpesa/providers/providers.dart';
import 'package:vick_mpesa/screens/home_screen.dart';
import 'package:vick_mpesa/screens/pay_screen.dart';
import 'package:vick_mpesa/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

Transaction _fakeTransaction({
  TransactionStatus status = TransactionStatus.success,
}) {
  return Transaction(
    id: 'txn-001',
    clientReference: 'REF001',
    providerReference: 'MPE123456',
    phoneNumber: '2547••••78',
    amount: 1500,
    currency: 'KES',
    type: TransactionType.stkPush,
    status: status,
    accountReference: 'Rent',
    description: 'Monthly rent',
    createdAt: DateTime(2026, 9, 3, 9, 45),
    updatedAt: DateTime(2026, 9, 3, 9, 46),
    completedAt: DateTime(2026, 9, 3, 9, 46),
  );
}

// ---------------------------------------------------------------------------
// Model tests
// ---------------------------------------------------------------------------

void main() {
  group('TransactionStatus', () {
    test('fromString maps correctly', () {
      expect(TransactionStatus.fromString('SUCCESS'), TransactionStatus.success);
      expect(TransactionStatus.fromString('FAILED'), TransactionStatus.failed);
      expect(TransactionStatus.fromString('PENDING'), TransactionStatus.pending);
      expect(TransactionStatus.fromString('UNKNOWN_VALUE'), TransactionStatus.unknown);
    });

    test('isTerminal is correct', () {
      expect(TransactionStatus.success.isTerminal, isTrue);
      expect(TransactionStatus.failed.isTerminal, isTrue);
      expect(TransactionStatus.cancelled.isTerminal, isTrue);
      expect(TransactionStatus.pending.isTerminal, isFalse);
      expect(TransactionStatus.initiated.isTerminal, isFalse);
    });

    test('isPending is correct', () {
      expect(TransactionStatus.pending.isPending, isTrue);
      expect(TransactionStatus.initiated.isPending, isTrue);
      expect(TransactionStatus.created.isPending, isTrue);
      expect(TransactionStatus.success.isPending, isFalse);
    });
  });

  group('TransactionType', () {
    test('fromString maps correctly', () {
      expect(TransactionType.fromString('STK_PUSH'), TransactionType.stkPush);
      expect(TransactionType.fromString('B2C'), TransactionType.b2c);
    });

    test('displayName is human readable', () {
      expect(TransactionType.stkPush.displayName, 'Payment');
      expect(TransactionType.b2c.displayName, 'Sent');
    });
  });

  group('Transaction.fromJson', () {
    test('parses valid JSON', () {
      final json = {
        'id': 'abc-123',
        'client_reference': 'REF001',
        'provider_reference': 'MPE001',
        'phone_number': '2547••••78',
        'amount': 500.0,
        'currency': 'KES',
        'transaction_type': 'STK_PUSH',
        'status': 'SUCCESS',
        'account_reference': 'Rent',
        'description': 'Payment',
        'provider_response_description': null,
        'created_at': '2026-09-03T09:45:00Z',
        'updated_at': '2026-09-03T09:46:00Z',
        'completed_at': '2026-09-03T09:46:00Z',
      };
      final txn = Transaction.fromJson(json);
      expect(txn.id, 'abc-123');
      expect(txn.amount, 500.0);
      expect(txn.status, TransactionStatus.success);
      expect(txn.type, TransactionType.stkPush);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  group('PayScreen', () {
    testWidgets('renders payment form fields', (tester) async {
      await tester.pumpWidget(_wrap(const PayScreen()));
      await tester.pump();

      expect(find.text('Send Payment'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Amount (KSh)'), findsOneWidget);
      expect(find.text('Account reference'), findsOneWidget);
    });

    testWidgets('shows validation error for empty phone', (tester) async {
      await tester.pumpWidget(_wrap(const PayScreen()));
      await tester.pump();

      await tester.tap(find.text('Send Payment Request'));
      await tester.pump();

      expect(find.text('Phone number required'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid phone', (tester) async {
      await tester.pumpWidget(_wrap(const PayScreen()));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone number'), '0812345678');
      await tester.tap(find.text('Send Payment Request'));
      await tester.pump();

      expect(find.text('Enter a valid Kenyan phone number'), findsOneWidget);
    });

    testWidgets('shows validation error for zero amount', (tester) async {
      await tester.pumpWidget(_wrap(const PayScreen()));
      await tester.pump();

      // Enter valid phone, invalid amount
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '0712345678'); // phone
      await tester.enterText(fields.at(1), '0');          // amount
      await tester.tap(find.text('Send Payment Request'));
      await tester.pump();

      expect(find.text('Enter a whole KSh amount'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    testWidgets('shows loading state while transactions fetch', (tester) async {
      // Use a Completer that never completes — no pending timers
      final completer = Completer<List<Transaction>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith(
              (ref) => completer.future,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Complete to avoid pending future warning on teardown
      completer.complete([]);
    });

    testWidgets('shows empty state when no transactions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet.'), findsOneWidget);
    });

    testWidgets('shows transactions when loaded', (tester) async {
      final txns = [_fakeTransaction()];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith((ref) async => txns),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
    });
  });
}
