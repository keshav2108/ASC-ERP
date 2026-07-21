import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../invoices/data/invoice_model.dart';
import '../../invoices/data/invoice_provider.dart';
import '../data/payment_model.dart';
import '../data/payment_provider.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  const RecordPaymentDialog({this.initialInvoice, super.key});

  final Invoice? initialInvoice;

  @override
  ConsumerState<RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();

  int? _selectedInvoiceId;

  String _selectedPaymentMethod = 'CASH';

  InvoicePaymentSummary? _summary;

  bool _isLoadingSummary = false;
  bool _isSaving = false;

  String? _errorMessage;

  int _summaryRequestId = 0;

  @override
  void initState() {
    super.initState();

    _selectedInvoiceId = widget.initialInvoice?.id;

    if (_selectedInvoiceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _loadInvoiceSummary(_selectedInvoiceId!, fillBalanceAmount: true);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();

    super.dispose();
  }

  Future<void> _onInvoiceChanged(int? invoiceId) async {
    if (invoiceId == _selectedInvoiceId) {
      return;
    }

    setState(() {
      _selectedInvoiceId = invoiceId;
      _summary = null;
      _errorMessage = null;

      _amountController.clear();
    });

    if (invoiceId == null) {
      return;
    }

    await _loadInvoiceSummary(invoiceId, fillBalanceAmount: true);
  }

  Future<void> _loadInvoiceSummary(
    int invoiceId, {
    required bool fillBalanceAmount,
  }) async {
    final requestId = ++_summaryRequestId;

    setState(() {
      _isLoadingSummary = true;
      _errorMessage = null;
    });

    try {
      final summary = await ref
          .read(paymentServiceProvider)
          .getInvoicePayments(invoiceId);

      if (!mounted || requestId != _summaryRequestId) {
        return;
      }

      setState(() {
        _summary = summary;
        _isLoadingSummary = false;

        if (fillBalanceAmount && summary.balanceAmount > 0) {
          _amountController.text = summary.balanceAmount.toStringAsFixed(2);

          _amountController.selection = TextSelection.collapsed(
            offset: _amountController.text.length,
          );
        }
      });
    } catch (error) {
      if (!mounted || requestId != _summaryRequestId) {
        return;
      }

      setState(() {
        _isLoadingSummary = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _recordPayment() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final invoiceId = _selectedInvoiceId;
    final summary = _summary;

    if (invoiceId == null) {
      setState(() {
        _errorMessage = 'Select an invoice.';
      });

      return;
    }

    if (summary == null) {
      setState(() {
        _errorMessage =
            'Invoice balance is not available. '
            'Reload the invoice and try again.';
      });

      return;
    }

    if (summary.isPaid || summary.balanceAmount <= 0) {
      setState(() {
        _errorMessage = 'This invoice is already fully paid.';
      });

      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Enter a valid payment amount.';
      });

      return;
    }

    if (amount > summary.balanceAmount + 0.001) {
      setState(() {
        _errorMessage =
            'Payment cannot exceed the remaining '
            'balance of ${_money(summary.balanceAmount)}.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final payment = await ref
          .read(paymentProvider.notifier)
          .recordPayment(
            PaymentCreateInput(
              invoiceId: invoiceId,
              amount: amount,
              paymentMethod: _selectedPaymentMethod,
              transactionReference: _referenceController.text,
              remarks: _remarksController.text,
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(payment);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesState = ref.watch(invoiceProvider);

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 880),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildInvoiceField(invoicesState),
                  const SizedBox(height: 20),
                  _buildInvoiceSummary(),
                  const SizedBox(height: 22),
                  _buildPaymentFields(),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _referenceController,
                    enabled: !_isSaving,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Transaction reference',
                      hintText: 'UPI ID, transaction ID, card reference, etc.',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _remarksController,
                    enabled: !_isSaving,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      hintText: 'Optional payment notes',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _PaymentErrorBox(message: _errorMessage!),
                  ],
                  const SizedBox(height: 26),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.payments_rounded,
            color: AppColors.success,
            size: 29,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record Payment',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Record a full or partial invoice payment.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildInvoiceField(AsyncValue<List<Invoice>> invoicesState) {
    return invoicesState.when(
      data: (invoices) {
        final payableInvoices =
            invoices.where((invoice) => invoice.canAcceptPayment).toList()
              ..sort(
                (first, second) => second.createdAt.compareTo(first.createdAt),
              );

        final selectedInvoiceExists =
            _selectedInvoiceId != null &&
            payableInvoices.any((invoice) => invoice.id == _selectedInvoiceId);

        final selectedValue = selectedInvoiceExists ? _selectedInvoiceId : null;

        if (payableInvoices.isEmpty) {
          return TextFormField(
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Invoice',
              hintText: 'No unpaid invoice is available',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          );
        }

        return DropdownButtonFormField<int>(
          key: ValueKey('payment-invoice-$selectedValue'),
          initialValue: selectedValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Invoice',
            hintText: 'Select an unpaid invoice',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
          items: payableInvoices.map((invoice) {
            return DropdownMenuItem<int>(
              value: invoice.id,
              child: Text(
                '${invoice.invoiceCode} — '
                '${invoice.customer.fullName} — '
                '${_money(invoice.totalAmount)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSaving ? null : _onInvoiceChanged,
          validator: (value) {
            if (value == null) {
              return 'Select an invoice.';
            }

            return null;
          },
        );
      },
      loading: () {
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Loading invoices',
            prefixIcon: Icon(Icons.receipt_long_outlined),
            suffixIcon: Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      },
      error: (error, stackTrace) {
        return TextField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Unable to load invoices',
            prefixIcon: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
            ),
            suffixIcon: IconButton(
              tooltip: 'Retry',
              onPressed: () {
                ref.invalidate(invoiceProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceSummary() {
    if (_selectedInvoiceId == null) {
      return const _PaymentInformationBox(
        icon: Icons.info_outline_rounded,
        message:
            'Select an invoice to view its '
            'paid amount and remaining balance.',
      );
    }

    if (_isLoadingSummary) {
      return const _PaymentInformationBox(
        icon: Icons.sync_rounded,
        message: 'Loading invoice payment summary...',
        showProgress: true,
      );
    }

    final summary = _summary;

    if (summary == null) {
      return _PaymentInformationBox(
        icon: Icons.refresh_rounded,
        message:
            'Invoice payment information could '
            'not be loaded.',
        actionLabel: 'Retry',
        onAction: () {
          _loadInvoiceSummary(_selectedInvoiceId!, fillBalanceAmount: false);
        },
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary.invoiceCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              _PaymentStatusBadge(status: summary.paymentStatus),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final total = _SummaryAmount(
                label: 'Invoice total',
                value: summary.totalAmount,
              );

              final paid = _SummaryAmount(
                label: 'Amount paid',
                value: summary.paidAmount,
              );

              final balance = _SummaryAmount(
                label: 'Balance due',
                value: summary.balanceAmount,
                emphasize: true,
              );

              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    total,
                    const SizedBox(height: 12),
                    paid,
                    const SizedBox(height: 12),
                    balance,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: total),
                  const SizedBox(width: 14),
                  Expanded(child: paid),
                  const SizedBox(width: 14),
                  Expanded(child: balance),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: summary.paymentProgress,
              minHeight: 8,
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(summary.paymentProgress * 100).toStringAsFixed(0)}% paid',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFields() {
    final amountField = TextFormField(
      controller: _amountController,
      enabled:
          !_isSaving &&
          !_isLoadingSummary &&
          _summary != null &&
          !_summary!.isPaid,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Payment amount',
        hintText: '0.00',
        prefixText: '₹ ',
        prefixIcon: Icon(Icons.currency_rupee_rounded),
      ),
      validator: (value) {
        final amount = double.tryParse(value?.trim() ?? '');

        if (amount == null || amount <= 0) {
          return 'Enter a valid amount.';
        }

        final balance = _summary?.balanceAmount;

        if (balance != null && amount > balance + 0.001) {
          return 'Maximum ${_money(balance)}.';
        }

        return null;
      },
    );

    final methodField = DropdownButtonFormField<String>(
      initialValue: _selectedPaymentMethod,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Payment method',
        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
      ),
      items: supportedPaymentMethods.map((method) {
        return DropdownMenuItem<String>(
          value: method,
          child: Text(_formatPaymentMethod(method)),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedPaymentMethod = value;
              });
            },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [amountField, const SizedBox(height: 18), methodField],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: amountField),
            const SizedBox(width: 18),
            Expanded(child: methodField),
          ],
        );
      },
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isSaving || _isLoadingSummary || _summary == null
              ? null
              : _recordPayment,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(_isSaving ? 'Recording...' : 'Record Payment'),
        ),
      ],
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.success.withValues(alpha: 0.09)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(value),
            style: TextStyle(
              color: emphasize ? AppColors.success : null,
              fontSize: 17,
              fontWeight: FontWeight.w800,
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

    final color = switch (normalized) {
      'PAID' => AppColors.success,
      'PARTIALLY_PAID' => Colors.orange,
      _ => AppColors.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _formatPaymentMethod(normalized),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentInformationBox extends StatelessWidget {
  const _PaymentInformationBox({
    required this.icon,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          if (showProgress)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: AppColors.primary),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
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

String _money(double value) {
  return '₹${value.toStringAsFixed(2)}';
}

String _formatPaymentMethod(String value) {
  return value
      .trim()
      .toLowerCase()
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
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
