import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 5);
  static const _maxPolls = 12; // 1 minute max
  int _pollCount = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _startPollingIfNeeded();
  }

  void _startPollingIfNeeded() {
    // Will check after first load whether polling is needed
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndPoll());
  }

  void _checkAndPoll() {
    final state = ref.read(transactionDetailProvider(widget.transactionId));
    state.whenData((txn) {
      if (!txn.status.isTerminal && _pollCount < _maxPolls) {
        _pollTimer ??= Timer.periodic(_pollInterval, (_) => _poll());
      }
    });
  }

  Future<void> _poll() async {
    _pollCount++;
    final txn = await ref.refresh(transactionDetailProvider(widget.transactionId).future);
    if (txn.status.isTerminal || _pollCount >= _maxPolls) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _syncPayment() async {
    setState(() => _syncing = true);
    try {
      await ref.read(paymentServiceProvider).syncPayment(widget.transactionId);
      ref.invalidate(transactionDetailProvider(widget.transactionId));
      ref.invalidate(transactionsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txnAsync = ref.watch(transactionDetailProvider(widget.transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: txnAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e.toString(),
            onRetry: () => ref.invalidate(
                transactionDetailProvider(widget.transactionId))),
        data: (txn) => _TransactionDetail(
          txn,
          syncing: _syncing,
          onSync: txn.status.isTerminal ? null : () => _syncPayment(),
        ),
      ),
    );
  }
}

class _TransactionDetail extends StatelessWidget {
  final Transaction txn;
  final bool syncing;
  final VoidCallback? onSync;
  const _TransactionDetail(this.txn, {required this.syncing, this.onSync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_KE');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status hero
          _StatusHero(txn),
          const SizedBox(height: 24),

          // Amount
          Center(
            child: Text(
              'KSh ${fmt.format(txn.amount)}',
              style: const TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 24),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow('Phone', txn.phoneNumber),
                  _DetailRow('Reference', txn.accountReference),
                  _DetailRow('Description', txn.description),
                  _DetailRow('Type', txn.type.displayName),
                  _DetailRow('Date', dateFmt.format(txn.createdAt.toLocal())),
                  if (txn.completedAt != null)
                    _DetailRow('Completed',
                        dateFmt.format(txn.completedAt!.toLocal())),
                  if (txn.providerReference != null)
                    _DetailRow('M-PESA Receipt', txn.providerReference!,
                        copyable: true),
                  _DetailRow('Transaction ID', txn.id, copyable: true),
                ],
              ),
            ),
          ),

          // Pending notice
          if (txn.status.isPending) ...[
            const SizedBox(height: 16),
            _PendingNotice(txn),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_outlined),
              label: const Text('Check status'),
            ),
          ],

          // Failure reason
          if (txn.status == TransactionStatus.failed &&
              txn.providerResponseDescription != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      txn.providerResponseDescription!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  final Transaction txn;
  const _StatusHero(this.txn);

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (txn.status) {
      TransactionStatus.success => (
          Icons.check_circle_outline,
          AppColors.success,
          'Payment Successful',
          'M-PESA has confirmed this transaction.'
        ),
      TransactionStatus.failed => (
          Icons.cancel_outlined,
          AppColors.error,
          'Payment Failed',
          'M-PESA did not complete this transaction.'
        ),
      TransactionStatus.pending ||
      TransactionStatus.initiated => (
          Icons.hourglass_empty_outlined,
          AppColors.pending,
          'Awaiting Confirmation',
          'Waiting for M-PESA to confirm. Do not retry yet.'
        ),
      TransactionStatus.timeout => (
          Icons.timer_off_outlined,
          AppColors.warning,
          'Request Timed Out',
          'We could not confirm the final status. Check your M-PESA messages.'
        ),
      _ => (
          Icons.help_outline,
          AppColors.textSecondary,
          'Status Unknown',
          'We could not determine the final status of this transaction.'
        ),
    };

    return Column(
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 8),
        Text(title,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _DetailRow(this.label, this.value, {this.copyable = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2)),
                );
              },
              child: const Icon(Icons.copy_outlined,
                  size: 16, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _PendingNotice extends StatelessWidget {
  final Transaction txn;
  const _PendingNotice(this.txn);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pending.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Waiting for M-PESA confirmation. '
              'Do not retry if you are unsure whether the payment went through.',
              style: TextStyle(fontSize: 12, color: AppColors.pending),
            ),
          ),
        ],
      ),
    );
  }
}
