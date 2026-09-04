import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key});

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController(text: 'Payment');
  final _descCtrl = TextEditingController(text: 'Payment');
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        phone: _phoneCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        reference: _refCtrl.text.trim(),
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final idempotencyKey = [
        _phoneCtrl.text.trim().replaceAll(' ', ''),
        _amountCtrl.text.trim(),
        DateTime.now().microsecondsSinceEpoch,
      ].join('-');
      final result = await ref.read(paymentServiceProvider).initiateStkPush(
            phoneNumber: _phoneCtrl.text.trim(),
            amount: double.parse(_amountCtrl.text.trim()),
            accountReference: _refCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            idempotencyKey: idempotencyKey,
          );
      if (!mounted) return;
      final txnId = result['transaction_id'] as String;
      context.pushReplacement('/transactions/$txnId');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the phone number that will receive the M-PESA prompt.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '07XX XXX XXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone number required';
                  final cleaned = v.trim().replaceAll(' ', '');
                  if (!RegExp(r'^(?:254|\+254|0)(7\d{8}|1\d{8})$').hasMatch(cleaned)) {
                    return 'Enter a valid Kenyan phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (KSh)',
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a whole KSh amount';
                  if (n > 150000) return 'Maximum amount is KSh 150,000';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account reference',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
                maxLength: 12,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Reference required';
                  if (!RegExp(r'^[A-Za-z0-9 _\-\.]+$').hasMatch(v.trim())) {
                    return 'Only letters, numbers, spaces, hyphens allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLength: 13,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Description required';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Payment Request'),
              ),
              const SizedBox(height: 12),
              const Text(
                'You will receive an M-PESA prompt on your phone to enter your PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String phone;
  final double amount;
  final String reference;

  const _ConfirmDialog({
    required this.phone,
    required this.amount,
    required this.reference,
  });

  String _maskPhone(String p) {
    final cleaned = p.replaceAll(' ', '');
    if (cleaned.length < 6) return '••••••';
    return '${cleaned.substring(0, 4)}••••${cleaned.substring(cleaned.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row('Amount', 'KSh ${amount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _Row('Phone', _maskPhone(phone)),
          const SizedBox(height: 8),
          _Row('Reference', reference),
          const SizedBox(height: 16),
          const Text(
            'An M-PESA prompt will be sent to the phone number above. '
            'Do not share your PIN with anyone.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}
