import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../job_cards/data/job_card_model.dart';
import '../../job_cards/data/job_card_provider.dart';
import '../data/invoice_model.dart';
import '../data/invoice_provider.dart';
import 'generate_invoice_dialog.dart';
import 'invoice_details_dialog.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedPaymentStatus = 'ALL';
  String _selectedInvoiceStatus = 'ALL';

  Object? get _currentUserRole {
    return ref.read(authProvider).user?['role'];
  }

  bool get _canManageInvoices {
    return AppPermissions.canManageInvoices(_currentUserRole);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedPaymentStatus = 'ALL';
      _selectedInvoiceStatus = 'ALL';
    });
  }

  Future<void> _generateInvoice(List<Invoice> existingInvoices) async {
    if (!_canManageInvoices) {
      _showMessage(
        'Only Admin or Accountant can generate invoices.',
        isError: true,
      );

      return;
    }

    var jobCardsState = ref.read(jobCardProvider);

    var jobCards = jobCardsState.value;

    if (jobCards == null) {
      await ref.read(jobCardProvider.notifier).refreshJobCards();

      jobCardsState = ref.read(jobCardProvider);

      jobCards = jobCardsState.value;
    }

    if (!mounted) {
      return;
    }

    if (jobCards == null) {
      _showMessage(
        'Unable to load Job Cards. Please refresh and try again.',
        isError: true,
      );

      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GenerateInvoiceDialog(
          jobCards: jobCards!,
          existingInvoices: existingInvoices,
          onGenerate: (input) async {
            await ref.read(invoiceProvider.notifier).generateInvoice(input);
          },
        );
      },
    );

    if (saved == true && mounted) {
      _showMessage('Invoice generated successfully.');
    }
  }

  void _showInvoiceDetails(Invoice invoice) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return InvoiceDetailsDialog(invoice: invoice);
      },
    );
  }

  Future<void> _cancelInvoice(Invoice invoice) async {
    if (!_canManageInvoices) {
      _showMessage(
        'Only Admin or Accountant can cancel invoices.',
        isError: true,
      );

      return;
    }

    if (invoice.isCancelled) {
      _showMessage('This invoice is already cancelled.', isError: true);

      return;
    }

    if (invoice.isPaid || invoice.isPartiallyPaid) {
      _showMessage(
        'A paid or partially paid invoice cannot be cancelled.',
        isError: true,
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel invoice?'),
          content: Text(
            '${invoice.invoiceCode} for '
            '${invoice.customer.fullName} '
            'will be marked as cancelled. '
            'The invoice record will remain saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Keep Invoice'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Invoice'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(invoiceProvider.notifier).cancelInvoice(invoice.id);

      if (!mounted) {
        return;
      }

      _showMessage('${invoice.invoiceCode} cancelled successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanError(error), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final invoicesState = ref.watch(invoiceProvider);

    final jobCardsState = ref.watch(jobCardProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(invoiceProvider.notifier).refreshInvoices(),
              ref.read(jobCardProvider.notifier).refreshJobCards(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            children: [
              invoicesState.when(
                data: (invoices) {
                  final jobCards = jobCardsState.value ?? <JobCard>[];

                  return _buildContent(
                    invoices: invoices,
                    jobCards: jobCards,
                    availableWidth: constraints.maxWidth,
                  );
                },
                loading: () => const _LoadingInvoices(),
                error: (error, stackTrace) {
                  return _InvoicesError(
                    message: _cleanError(error),
                    onRetry: () {
                      ref.read(invoiceProvider.notifier).refreshInvoices();
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required List<Invoice> invoices,
    required List<JobCard> jobCards,
    required double availableWidth,
  }) {
    final filteredInvoices = invoices.where((invoice) {
      final searchQuery = _searchQuery.trim().toLowerCase();

      final matchesSearch =
          searchQuery.isEmpty ||
          invoice.invoiceCode.toLowerCase().contains(searchQuery) ||
          invoice.customer.fullName.toLowerCase().contains(searchQuery) ||
          invoice.customer.mobile.toLowerCase().contains(searchQuery) ||
          invoice.customer.customerCode.toLowerCase().contains(searchQuery) ||
          invoice.jobCard.jobCode.toLowerCase().contains(searchQuery);

      final matchesPaymentStatus =
          _selectedPaymentStatus == 'ALL' ||
          _normalizeStatus(invoice.paymentStatus) == _selectedPaymentStatus;

      final matchesInvoiceStatus =
          _selectedInvoiceStatus == 'ALL' ||
          _normalizeStatus(invoice.status) == _selectedInvoiceStatus;

      return matchesSearch && matchesPaymentStatus && matchesInvoiceStatus;
    }).toList();

    final eligibleJobCount = _eligibleJobCardCount(jobCards, invoices);

    final hasFilters =
        _searchQuery.trim().isNotEmpty ||
        _selectedPaymentStatus != 'ALL' ||
        _selectedInvoiceStatus != 'ALL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InvoicesHeader(
          canGenerate: _canManageInvoices,
          eligibleJobCount: eligibleJobCount,
          onGenerate: () {
            _generateInvoice(invoices);
          },
          onRefresh: () {
            ref.read(invoiceProvider.notifier).refreshInvoices();

            ref.read(jobCardProvider.notifier).refreshJobCards();
          },
        ),
        const SizedBox(height: 20),
        _InvoiceSummaryCards(invoices: invoices),
        const SizedBox(height: 20),
        _InvoiceFilters(
          searchController: _searchController,
          selectedPaymentStatus: _selectedPaymentStatus,
          selectedInvoiceStatus: _selectedInvoiceStatus,
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onPaymentStatusChanged: (value) {
            setState(() {
              _selectedPaymentStatus = value ?? 'ALL';
            });
          },
          onInvoiceStatusChanged: (value) {
            setState(() {
              _selectedInvoiceStatus = value ?? 'ALL';
            });
          },
          onClear: _clearFilters,
          hasFilters: hasFilters,
        ),
        const SizedBox(height: 16),
        _InvoiceCountBar(
          visibleCount: filteredInvoices.length,
          totalCount: invoices.length,
        ),
        const SizedBox(height: 14),
        if (filteredInvoices.isEmpty)
          _EmptyInvoices(
            hasFilters: hasFilters,
            canGenerate: _canManageInvoices,
            eligibleJobCount: eligibleJobCount,
            onGenerate: () {
              _generateInvoice(invoices);
            },
            onClearFilters: _clearFilters,
          )
        else if (availableWidth >= 1020)
          _InvoicesTable(
            invoices: filteredInvoices,
            canManage: _canManageInvoices,
            onView: _showInvoiceDetails,
            onCancel: _cancelInvoice,
          )
        else
          _InvoicesCardList(
            invoices: filteredInvoices,
            canManage: _canManageInvoices,
            onView: _showInvoiceDetails,
            onCancel: _cancelInvoice,
          ),
      ],
    );
  }
}

class _InvoicesHeader extends StatelessWidget {
  const _InvoicesHeader({
    required this.canGenerate,
    required this.eligibleJobCount,
    required this.onGenerate,
    required this.onRefresh,
  });

  final bool canGenerate;
  final int eligibleJobCount;

  final VoidCallback onGenerate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
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
                    'Invoices',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    eligibleJobCount > 0
                        ? '$eligibleJobCount completed '
                              'Job Card${eligibleJobCount == 1 ? '' : 's'} '
                              'ready for invoicing.'
                        : 'Manage repair bills, GST and payment status.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            if (canGenerate)
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Generate Invoice'),
              ),
          ],
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: actions),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _InvoiceSummaryCards extends StatelessWidget {
  const _InvoiceSummaryCards({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final activeInvoices = invoices
        .where((invoice) => !invoice.isCancelled)
        .toList();

    final unpaidCount = activeInvoices
        .where((invoice) => _normalizeStatus(invoice.paymentStatus) == 'UNPAID')
        .length;

    final partiallyPaidCount = activeInvoices
        .where((invoice) => invoice.isPartiallyPaid)
        .length;

    final paidCount = activeInvoices.where((invoice) => invoice.isPaid).length;

    final totalBilling = activeInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.totalAmount,
    );

    final cards = [
      _InvoiceSummaryCard(
        icon: Icons.receipt_long_outlined,
        label: 'Active Invoices',
        value: activeInvoices.length.toString(),
        color: AppColors.primary,
      ),
      _InvoiceSummaryCard(
        icon: Icons.pending_actions_rounded,
        label: 'Unpaid',
        value: unpaidCount.toString(),
        color: AppColors.danger,
      ),
      _InvoiceSummaryCard(
        icon: Icons.timelapse_rounded,
        label: 'Partially Paid',
        value: partiallyPaidCount.toString(),
        color: AppColors.warning,
      ),
      _InvoiceSummaryCard(
        icon: Icons.check_circle_outline_rounded,
        label: 'Paid',
        value: paidCount.toString(),
        color: AppColors.success,
      ),
      _InvoiceSummaryCard(
        icon: Icons.currency_rupee_rounded,
        label: 'Total Billing',
        value: _money(totalBilling),
        color: AppColors.primary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : constraints.maxWidth < 1000
            ? (constraints.maxWidth - 14) / 2
            : (constraints.maxWidth - 56) / 5;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((card) {
            return SizedBox(width: cardWidth, child: card);
          }).toList(),
        );
      },
    );
  }
}

class _InvoiceSummaryCard extends StatelessWidget {
  const _InvoiceSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceFilters extends StatelessWidget {
  const _InvoiceFilters({
    required this.searchController,
    required this.selectedPaymentStatus,
    required this.selectedInvoiceStatus,
    required this.onSearchChanged,
    required this.onPaymentStatusChanged,
    required this.onInvoiceStatusChanged,
    required this.onClear,
    required this.hasFilters,
  });

  final TextEditingController searchController;

  final String selectedPaymentStatus;
  final String selectedInvoiceStatus;

  final ValueChanged<String> onSearchChanged;

  final ValueChanged<String?> onPaymentStatusChanged;

  final ValueChanged<String?> onInvoiceStatusChanged;

  final VoidCallback onClear;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchField = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search invoices',
              hintText: 'Invoice, customer, mobile or Job Card',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          );

          final paymentFilter = DropdownButtonFormField<String>(
            initialValue: selectedPaymentStatus,
            decoration: const InputDecoration(
              labelText: 'Payment status',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All payments')),
              DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid')),
              DropdownMenuItem(
                value: 'PARTIALLY_PAID',
                child: Text('Partially Paid'),
              ),
              DropdownMenuItem(value: 'PAID', child: Text('Paid')),
            ],
            onChanged: onPaymentStatusChanged,
          );

          final invoiceFilter = DropdownButtonFormField<String>(
            initialValue: selectedInvoiceStatus,
            decoration: const InputDecoration(
              labelText: 'Invoice status',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All invoices')),
              DropdownMenuItem(value: 'GENERATED', child: Text('Generated')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
            onChanged: onInvoiceStatusChanged,
          );

          final clearButton = OutlinedButton.icon(
            onPressed: hasFilters ? onClear : null,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: const Text('Clear'),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 14),
                paymentFilter,
                const SizedBox(height: 14),
                invoiceFilter,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: clearButton),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: searchField),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: paymentFilter),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: invoiceFilter),
              const SizedBox(width: 14),
              SizedBox(height: 56, child: clearButton),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceCountBar extends StatelessWidget {
  const _InvoiceCountBar({
    required this.visibleCount,
    required this.totalCount,
  });

  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$visibleCount of $totalCount '
          'invoice${totalCount == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InvoicesTable extends StatelessWidget {
  const _InvoicesTable({
    required this.invoices,
    required this.canManage,
    required this.onView,
    required this.onCancel,
  });

  final List<Invoice> invoices;
  final bool canManage;

  final ValueChanged<Invoice> onView;
  final ValueChanged<Invoice> onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    AppColors.primary.withValues(alpha: 0.07),
                  ),
                  columns: const [
                    DataColumn(label: Text('Invoice')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Job Card')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Payment')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: invoices.map((invoice) {
                    return DataRow(
                      cells: [
                        DataCell(
                          InkWell(
                            onTap: () {
                              onView(invoice);
                            },
                            child: Text(
                              invoice.invoiceCode,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.customer.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  invoice.customer.mobile,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            invoice.jobCard.jobCode,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(
                          Text(
                            _money(invoice.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DataCell(
                          _StatusBadge(
                            label: _formatStatus(invoice.paymentStatus),
                            color: _paymentStatusColor(invoice.paymentStatus),
                          ),
                        ),
                        DataCell(
                          _StatusBadge(
                            label: _formatStatus(invoice.status),
                            color: invoice.isCancelled
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                        DataCell(Text(_formatDate(invoice.createdAt))),
                        DataCell(
                          _InvoiceActions(
                            invoice: invoice,
                            canManage: canManage,
                            onView: onView,
                            onCancel: onCancel,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvoicesCardList extends StatelessWidget {
  const _InvoicesCardList({
    required this.invoices,
    required this.canManage,
    required this.onView,
    required this.onCancel,
  });

  final List<Invoice> invoices;
  final bool canManage;

  final ValueChanged<Invoice> onView;
  final ValueChanged<Invoice> onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < invoices.length; index++) ...[
          _InvoiceCard(
            invoice: invoices[index],
            canManage: canManage,
            onView: onView,
            onCancel: onCancel,
          ),
          if (index != invoices.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.canManage,
    required this.onView,
    required this.onCancel,
  });

  final Invoice invoice;
  final bool canManage;

  final ValueChanged<Invoice> onView;
  final ValueChanged<Invoice> onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          onView(invoice);
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
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
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceCode,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDateTime(invoice.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _InvoiceActions(
                    invoice: invoice,
                    canManage: canManage,
                    onView: onView,
                    onCancel: onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                invoice.customer.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${invoice.customer.mobile} • '
                '${invoice.jobCard.jobCode}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatusBadge(
                    label: _formatStatus(invoice.paymentStatus),
                    color: _paymentStatusColor(invoice.paymentStatus),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: _formatStatus(invoice.status),
                    color: invoice.isCancelled
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  const Spacer(),
                  Text(
                    _money(invoice.totalAmount),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceActions extends StatelessWidget {
  const _InvoiceActions({
    required this.invoice,
    required this.canManage,
    required this.onView,
    required this.onCancel,
  });

  final Invoice invoice;
  final bool canManage;

  final ValueChanged<Invoice> onView;
  final ValueChanged<Invoice> onCancel;

  @override
  Widget build(BuildContext context) {
    final canCancel =
        canManage &&
        !invoice.isCancelled &&
        !invoice.isPaid &&
        !invoice.isPartiallyPaid;

    return PopupMenuButton<String>(
      tooltip: 'Invoice actions',
      onSelected: (value) {
        switch (value) {
          case 'VIEW':
            onView(invoice);
          case 'CANCEL':
            onCancel(invoice);
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: 'VIEW',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_outlined),
              title: Text('View Invoice'),
            ),
          ),
          if (canCancel)
            const PopupMenuItem(
              value: 'CANCEL',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cancel_outlined, color: AppColors.danger),
                title: Text(
                  'Cancel Invoice',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ),
        ];
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices({
    required this.hasFilters,
    required this.canGenerate,
    required this.eligibleJobCount,
    required this.onGenerate,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final bool canGenerate;
  final int eligibleJobCount;

  final VoidCallback onGenerate;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 35,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilters ? 'No matching invoices' : 'No invoices generated yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Change or clear the current search and filters.'
                : eligibleJobCount > 0
                ? '$eligibleJobCount completed Job Card'
                      '${eligibleJobCount == 1 ? ' is' : 's are'} '
                      'ready for invoicing.'
                : 'Complete a Job Card before generating its invoice.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (hasFilters)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Clear Filters'),
            )
          else if (canGenerate)
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Generate Invoice'),
            ),
        ],
      ),
    );
  }
}

class _LoadingInvoices extends StatelessWidget {
  const _LoadingInvoices();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 120),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading invoices...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicesError extends StatelessWidget {
  const _InvoicesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 42,
          ),
          const SizedBox(height: 14),
          const Text(
            'Unable to load invoices',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

int _eligibleJobCardCount(List<JobCard> jobCards, List<Invoice> invoices) {
  final invoicedJobCardIds = invoices
      .map((invoice) => invoice.jobCardId)
      .toSet();

  return jobCards.where((jobCard) {
    final status = _normalizeStatus(jobCard.status);

    return (status == 'COMPLETED' || status == 'READY_FOR_DELIVERY') &&
        !invoicedJobCardIds.contains(jobCard.id);
  }).length;
}

Color _paymentStatusColor(String status) {
  return switch (_normalizeStatus(status)) {
    'PAID' => AppColors.success,
    'PARTIALLY_PAID' => AppColors.warning,
    'UNPAID' => AppColors.danger,
    _ => AppColors.primary,
  };
}

String _money(double value) {
  return '₹${value.toStringAsFixed(2)}';
}

String _formatDate(DateTime date) {
  return '${_twoDigits(date.day)}/'
      '${_twoDigits(date.month)}/'
      '${date.year}';
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} '
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
      .map(
        (part) =>
            '${part[0]}'
            '${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _cleanError(Object error) {
  final message = error.toString().trim();

  if (message.startsWith('Exception: ')) {
    return message.substring(11);
  }

  return message;
}
