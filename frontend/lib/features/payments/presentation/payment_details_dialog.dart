import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/payment_model.dart';
import '../data/payment_provider.dart';

class PaymentDetailsDialog extends ConsumerStatefulWidget {
  const PaymentDetailsDialog({
    required this.payment,
    required this.canCancel,
    super.key,
  });

  final Payment payment;
  final bool canCancel;

  @override
  ConsumerState<PaymentDetailsDialog> createState() =>
      _PaymentDetailsDialogState();
}

class _PaymentDetailsDialogState extends ConsumerState<PaymentDetailsDialog> {
  late Payment _payment;

  bool _isCancelling = false;
  bool _didChange = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _payment = widget.payment;
  }

  bool get _canCancelPayment {
    return widget.canCancel && _payment.isSuccessful && !_payment.isCancelled;
  }

  void _close() {
    if (_isCancelling) {
      return;
    }

    Navigator.of(context).pop(_didChange ? _payment : null);
  }

  Future<void> _cancelPayment() async {
    if (!_canCancelPayment) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
          title: const Text('Cancel recorded payment?'),
          content: Text(
            '${_payment.paymentCode} for '
            '${_money(_payment.amount)} will be cancelled.\n\n'
            'The invoice payment status and outstanding '
            'balance will be recalculated automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Keep Payment'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
      _errorMessage = null;
    });

    try {
      final cancelledPayment = await ref
          .read(paymentProvider.notifier)
          .cancelPayment(_payment.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _payment = cancelledPayment;
        _isCancelling = false;
        _didChange = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${cancelledPayment.paymentCode} '
            'cancelled successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCancelling = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryState = ref.watch(
      invoicePaymentSummaryProvider(_payment.invoiceId),
    );

    return PopScope(
      canPop: !_isCancelling,
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 880),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 26),
                _buildAmountCard(),
                const SizedBox(height: 22),
                _PaymentSection(
                  title: 'Payment Information',
                  icon: Icons.payments_outlined,
                  children: [
                    _PaymentDetailsRow(
                      label: 'Payment code',
                      value: _payment.paymentCode,
                    ),
                    _PaymentDetailsRow(
                      label: 'Invoice ID',
                      value: '#${_payment.invoiceId}',
                    ),
                    _PaymentDetailsRow(
                      label: 'Payment method',
                      value: _payment.formattedMethod,
                    ),
                    _PaymentDetailsRow(
                      label: 'Payment status',
                      value: _formatStatus(_payment.status),
                    ),
                    _PaymentDetailsRow(
                      label: 'Paid at',
                      value: _formatDateTime(_payment.paidAt),
                    ),
                    _PaymentDetailsRow(
                      label: 'Recorded at',
                      value: _formatDateTime(_payment.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PaymentSection(
                  title: 'Transaction Details',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    _PaymentDetailsRow(
                      label: 'Transaction reference',
                      value: _payment.transactionReference ?? 'Not provided',
                    ),
                    _PaymentDetailsRow(
                      label: 'Remarks',
                      value: _payment.remarks ?? 'No remarks',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInvoiceSummary(summaryState),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  _PaymentErrorBox(message: _errorMessage!),
                ],
                const SizedBox(height: 28),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final statusColor = _payment.isCancelled
        ? AppColors.danger
        : AppColors.success;

    final icon = _payment.isCancelled
        ? Icons.money_off_csred_outlined
        : Icons.verified_rounded;

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: statusColor, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _payment.paymentCode,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _payment.isCancelled
                    ? 'This payment has been cancelled.'
                    : 'Payment recorded successfully.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        _PaymentStatusBadge(status: _payment.status),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Close',
          onPressed: _isCancelling ? null : _close,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _payment.isCancelled
              ? [
                  AppColors.danger.withValues(alpha: 0.10),
                  AppColors.danger.withValues(alpha: 0.04),
                ]
              : [
                  AppColors.success.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _payment.isCancelled
              ? AppColors.danger.withValues(alpha: 0.22)
              : AppColors.success.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _paymentMethodIcon(_payment.paymentMethod),
              color: _payment.isCancelled
                  ? AppColors.danger
                  : AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Amount',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(_payment.amount),
                  style: TextStyle(
                    color: _payment.isCancelled
                        ? AppColors.danger
                        : AppColors.success,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    decoration: _payment.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _payment.formattedMethod,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary(AsyncValue<InvoicePaymentSummary> summaryState) {
    return _PaymentSection(
      title: 'Invoice Payment Summary',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        summaryState.when(
          data: (summary) {
            return Column(
              children: [
                _PaymentDetailsRow(
                  label: 'Invoice code',
                  value: summary.invoiceCode,
                ),
                _PaymentDetailsRow(
                  label: 'Invoice total',
                  value: _money(summary.totalAmount),
                ),
                _PaymentDetailsRow(
                  label: 'Successful payments',
                  value: _money(summary.paidAmount),
                ),
                _PaymentDetailsRow(
                  label: 'Balance due',
                  value: _money(summary.balanceAmount),
                  emphasize: summary.balanceAmount > 0,
                ),
                _PaymentDetailsRow(
                  label: 'Payment status',
                  value: _formatStatus(summary.paymentStatus),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: summary.paymentProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(summary.paymentProgress * 100).toStringAsFixed(0)}% paid',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text(
                      'Loading invoice summary...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          },
          error: (error, stackTrace) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Unable to load invoice summary.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(
                        invoicePaymentSummaryProvider(_payment.invoiceId),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isCancelling ? null : _close,
          child: const Text('Close'),
        ),
        if (_canCancelPayment) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _isCancelling ? null : _cancelPayment,
            icon: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Payment'),
          ),
        ],
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _PaymentDetailsRow extends StatelessWidget {
  const _PaymentDetailsRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: emphasize ? AppColors.danger : null,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();

    final color = normalized == 'CANCELLED'
        ? AppColors.danger
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _formatStatus(normalized),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentErrorBox extends StatelessWidget {
  const _PaymentErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _paymentMethodIcon(String method) {
  return switch (method.trim().toUpperCase()) {
    'CASH' => Icons.payments_outlined,
    'UPI' => Icons.qr_code_2_rounded,
    'CARD' => Icons.credit_card_rounded,
    'BANK_TRANSFER' => Icons.account_balance_rounded,
    _ => Icons.account_balance_wallet_outlined,
  };
}

String _money(double value) {
  return '₹${value.toStringAsFixed(2)}';
}

String _formatStatus(String value) {
  return value
      .trim()
      .toLowerCase()
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();

  final hour = local.hour > 12
      ? local.hour - 12
      : local.hour == 0
      ? 12
      : local.hour;

  final minute = local.minute.toString().padLeft(2, '0');

  final period = local.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year '
      '${hour.toString().padLeft(2, '0')}:$minute $period';
}

String _cleanError(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('ApiException: ', '');
}
