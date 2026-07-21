import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/invoice_model.dart';

class InvoiceDetailsDialog extends StatelessWidget {
  const InvoiceDetailsDialog({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    final dialogWidth = screenSize.width < 960 ? screenSize.width - 32 : 900.0;

    final dialogHeight = screenSize.height < 820
        ? screenSize.height - 32
        : 780.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInvoiceSummary(context),
                    const SizedBox(height: 22),
                    _buildPartiesSection(context),
                    const SizedBox(height: 22),
                    _buildItemsSection(context),
                    const SizedBox(height: 22),
                    _buildTotalsSection(context),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceCode,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generated on ${_formatDateTime(invoice.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: _formatStatus(invoice.paymentStatus),
            color: _paymentStatusColor(invoice.paymentStatus),
            icon: _paymentStatusIcon(invoice.paymentStatus),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Close',
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.11),
            AppColors.primary.withValues(alpha: 0.035),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            _SummaryMetric(
              icon: Icons.engineering_outlined,
              label: 'Job Card',
              value: invoice.jobCard.jobCode,
            ),
            _SummaryMetric(
              icon: Icons.person_outline_rounded,
              label: 'Customer',
              value: invoice.customer.fullName,
            ),
            _SummaryMetric(
              icon: Icons.currency_rupee_rounded,
              label: 'Invoice Total',
              value: _money(invoice.totalAmount),
              valueColor: AppColors.primary,
            ),
            _SummaryMetric(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Payment',
              value: _formatStatus(invoice.paymentStatus),
              valueColor: _paymentStatusColor(invoice.paymentStatus),
            ),
          ];

          if (constraints.maxWidth < 650) {
            return Column(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  cards[index],
                  if (index != cards.length - 1) const SizedBox(height: 14),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPartiesSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final customerCard = _InformationCard(
          icon: Icons.person_outline_rounded,
          title: 'Customer Details',
          children: [
            _InformationRow(
              label: 'Customer code',
              value: invoice.customer.customerCode,
            ),
            _InformationRow(
              label: 'Full name',
              value: invoice.customer.fullName,
            ),
            _InformationRow(label: 'Mobile', value: invoice.customer.mobile),
            if (invoice.customer.email != null)
              _InformationRow(label: 'Email', value: invoice.customer.email!),
            if (invoice.customer.formattedAddress.isNotEmpty)
              _InformationRow(
                label: 'Address',
                value: invoice.customer.formattedAddress,
                showDivider: false,
              ),
          ],
        );

        final jobCardCard = _InformationCard(
          icon: Icons.handyman_outlined,
          title: 'Repair Details',
          children: [
            _InformationRow(label: 'Job Card', value: invoice.jobCard.jobCode),
            _InformationRow(
              label: 'Job status',
              value: _formatStatus(invoice.jobCard.status),
            ),
            _InformationRow(
              label: 'Service Request ID',
              value: invoice.jobCard.serviceRequestId.toString(),
            ),
            _InformationRow(
              label: 'Technician ID',
              value: invoice.jobCard.technicianId.toString(),
            ),
            if (invoice.jobCard.diagnosis != null)
              _InformationRow(
                label: 'Diagnosis',
                value: invoice.jobCard.diagnosis!,
              ),
            if (invoice.jobCard.repairNotes != null)
              _InformationRow(
                label: 'Repair notes',
                value: invoice.jobCard.repairNotes!,
                showDivider: false,
              ),
          ],
        );

        if (constraints.maxWidth < 720) {
          return Column(
            children: [customerCard, const SizedBox(height: 18), jobCardCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: customerCard),
            const SizedBox(width: 18),
            Expanded(child: jobCardCard),
          ],
        );
      },
    );
  }

  Widget _buildItemsSection(BuildContext context) {
    return _SectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Invoice Items',
      subtitle:
          '${invoice.items.length} billing item${invoice.items.length == 1 ? '' : 's'}',
      child: invoice.items.isEmpty
          ? const _EmptyInvoiceItems()
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < invoice.items.length;
                        index++
                      ) ...[
                        _InvoiceItemCard(item: invoice.items[index]),
                        if (index != invoice.items.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                }

                return _InvoiceItemsTable(items: invoice.items);
              },
            ),
    );
  }

  Widget _buildTotalsSection(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 430,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            _AmountRow(label: 'Labour amount', amount: invoice.labourAmount),
            _AmountRow(
              label: 'Spare parts amount',
              amount: invoice.partsAmount,
            ),
            _AmountRow(
              label: 'Subtotal',
              amount: invoice.subtotal,
              emphasized: true,
            ),
            if (invoice.discountAmount > 0)
              _AmountRow(
                label: 'Discount',
                amount: -invoice.discountAmount,
                valueColor: AppColors.success,
              ),
            _AmountRow(label: 'Taxable amount', amount: invoice.taxableAmount),
            _AmountRow(
              label: 'GST (${_percentage(invoice.gstPercentage)})',
              amount: invoice.gstAmount,
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _money(invoice.totalAmount),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final statusColor = invoice.isCancelled
        ? AppColors.danger
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            invoice.isCancelled
                ? Icons.cancel_outlined
                : Icons.verified_outlined,
            color: statusColor,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              invoice.isCancelled
                  ? 'This invoice has been cancelled.'
                  : 'Invoice status: ${_formatStatus(invoice.status)}',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.done_rounded),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                ),
              )
            : null,
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
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _InvoiceItemsTable extends StatelessWidget {
  const _InvoiceItemsTable({required this.items});

  final List<InvoiceItem> items;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            AppColors.primary.withValues(alpha: 0.07),
          ),
          columns: const [
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Qty'), numeric: true),
            DataColumn(label: Text('Unit Price'), numeric: true),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: items.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      item.description,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                DataCell(_ItemTypeChip(item: item)),
                DataCell(Text(item.quantity.toString())),
                DataCell(Text(_money(item.unitPrice))),
                DataCell(
                  Text(
                    _money(item.totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InvoiceItemCard extends StatelessWidget {
  const _InvoiceItemCard({required this.item});

  final InvoiceItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _ItemTypeChip(item: item),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _MiniValue(
                  label: 'Quantity',
                  value: item.quantity.toString(),
                ),
              ),
              Expanded(
                child: _MiniValue(
                  label: 'Unit price',
                  value: _money(item.unitPrice),
                ),
              ),
              Expanded(
                child: _MiniValue(
                  label: 'Total',
                  value: _money(item.totalPrice),
                  valueColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTypeChip extends StatelessWidget {
  const _ItemTypeChip({required this.item});

  final InvoiceItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isLabour ? AppColors.primary : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.isLabour ? 'Labour' : 'Spare Part',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _EmptyInvoiceItems extends StatelessWidget {
  const _EmptyInvoiceItems();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppColors.textSecondary,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'No line items were recorded.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final double amount;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized ? null : AppColors.textSecondary,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              color: valueColor,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _paymentStatusColor(String status) {
  return switch (_normalizeStatus(status)) {
    'PAID' => AppColors.success,
    'PARTIALLY_PAID' => AppColors.warning,
    'UNPAID' => AppColors.danger,
    _ => AppColors.primary,
  };
}

IconData _paymentStatusIcon(String status) {
  return switch (_normalizeStatus(status)) {
    'PAID' => Icons.check_circle_outline_rounded,
    'PARTIALLY_PAID' => Icons.timelapse_rounded,
    'UNPAID' => Icons.pending_outlined,
    _ => Icons.info_outline_rounded,
  };
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';

  return '$sign₹${value.abs().toStringAsFixed(2)}';
}

String _percentage(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toStringAsFixed(0)}%';
  }

  return '${value.toStringAsFixed(2)}%';
}

String _formatDateTime(DateTime date) {
  return '${_twoDigits(date.day)}/'
      '${_twoDigits(date.month)}/'
      '${date.year} '
      '${_twoDigits(date.hour)}:'
      '${_twoDigits(date.minute)}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String _normalizeStatus(String value) {
  return value.trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
}

String _formatStatus(String value) {
  final normalized = _normalizeStatus(value);

  return normalized
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}
