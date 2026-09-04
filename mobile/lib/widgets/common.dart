import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      TransactionStatus.success   => (AppColors.success, 'Completed', Icons.check_circle_outline),
      TransactionStatus.failed    => (AppColors.error,   'Failed',    Icons.cancel_outlined),
      TransactionStatus.pending   => (AppColors.pending, 'Pending',   Icons.hourglass_empty),
      TransactionStatus.initiated => (AppColors.pending, 'Sent',      Icons.send_outlined),
      TransactionStatus.cancelled => (AppColors.warning, 'Cancelled', Icons.block_outlined),
      TransactionStatus.timeout   => (AppColors.warning, 'Timed out', Icons.timer_off_outlined),
      _                           => (AppColors.textSecondary, 'Unknown', Icons.help_outline),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction list tile
// ---------------------------------------------------------------------------

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_KE');
    final dateFmt = DateFormat('d MMM, HH:mm');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _TypeIcon(transaction.type, transaction.status),
      title: Text(
        transaction.accountReference,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateFmt.format(transaction.createdAt.toLocal()),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          StatusBadge(transaction.status),
        ],
      ),
      trailing: Text(
        'KSh ${fmt.format(transaction.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: transaction.status == TransactionStatus.success
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        ),
      ),
      isThreeLine: true,
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final TransactionType type;
  final TransactionStatus status;
  const _TypeIcon(this.type, this.status);

  @override
  Widget build(BuildContext context) {
    final color = status == TransactionStatus.success
        ? AppColors.primary
        : AppColors.textSecondary;
    final icon = switch (type) {
      TransactionType.stkPush => Icons.payment_outlined,
      TransactionType.b2c     => Icons.arrow_upward_outlined,
      TransactionType.c2b     => Icons.arrow_downward_outlined,
      TransactionType.b2b     => Icons.business_outlined,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / error states
// ---------------------------------------------------------------------------

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
