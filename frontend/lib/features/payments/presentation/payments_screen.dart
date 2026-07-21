import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../data/payment_model.dart';
import '../data/payment_provider.dart';
import 'payment_details_dialog.dart';
import 'record_payment_dialog.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedMethod = 'ALL';

  Object? get _currentRole {
    return ref.read(authProvider).user?['role'];
  }

  bool get _canRecordPayments {
    return AppPermissions.canRecordPayments(_currentRole);
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _recordPayment() async {
    if (!_canRecordPayments) {
      _showMessage(
        'Only Admin or Accountant can record payments.',
        isError: true,
      );

      return;
    }

    final payment = await showDialog<Payment>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const RecordPaymentDialog();
      },
    );

    if (payment == null || !mounted) {
      return;
    }

    _showMessage('${payment.paymentCode} recorded successfully.');
  }

  Future<void> _viewPayment(Payment payment) async {
    await showDialog<Payment?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PaymentDetailsDialog(
          payment: payment,
          canCancel: _canRecordPayments,
        );
      },
    );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedStatus = 'ALL';
      _selectedMethod = 'ALL';
    });
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
    final paymentState = ref.watch(paymentProvider);

    final role = ref.watch(authProvider.select((state) => state.user?['role']));

    final canRecord = AppPermissions.canRecordPayments(role);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(paymentProvider.notifier).refreshPayments();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
            children: [
              _PaymentsHeader(
                canRecord: canRecord,
                onRecordPayment: _recordPayment,
                onRefresh: () {
                  ref.read(paymentProvider.notifier).refreshPayments();
                },
              ),
              const SizedBox(height: 24),
              paymentState.when(
                data: (payments) {
                  return _buildPaymentsContent(payments, canRecord);
                },
                loading: () {
                  return const _PaymentsLoading();
                },
                error: (error, stackTrace) {
                  return _PaymentsError(
                    message: error.toString(),
                    onRetry: () {
                      ref.read(paymentProvider.notifier).refreshPayments();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentsContent(List<Payment> payments, bool canRecord) {
    final sortedPayments = [...payments]
      ..sort((first, second) => second.paidAt.compareTo(first.paidAt));

    final successfulPayments = sortedPayments
        .where((payment) => payment.isSuccessful)
        .toList();

    final cancelledPayments = sortedPayments
        .where((payment) => payment.isCancelled)
        .toList();

    final totalCollected = successfulPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );

    final todayCollected = successfulPayments
        .where((payment) => _isToday(payment.paidAt))
        .fold<double>(0, (total, payment) => total + payment.amount);

    final filteredPayments = sortedPayments.where((payment) {
      final query = _searchQuery.trim().toLowerCase();

      final searchableText = [
        payment.paymentCode,
        payment.invoiceId.toString(),
        payment.paymentMethod,
        payment.formattedMethod,
        payment.transactionReference ?? '',
        payment.remarks ?? '',
      ].join(' ').toLowerCase();

      final matchesSearch = query.isEmpty || searchableText.contains(query);

      final matchesStatus =
          _selectedStatus == 'ALL' ||
          payment.status.trim().toUpperCase() == _selectedStatus;

      final matchesMethod =
          _selectedMethod == 'ALL' ||
          payment.paymentMethod.trim().toUpperCase() == _selectedMethod;

      return matchesSearch && matchesStatus && matchesMethod;
    }).toList();

    final hasFilters =
        _searchQuery.trim().isNotEmpty ||
        _selectedStatus != 'ALL' ||
        _selectedMethod != 'ALL';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(
          '${payments.length}-'
          '$_selectedStatus-$_selectedMethod-'
          '$_searchQuery',
        ),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PaymentSummaryGrid(
            totalCollected: totalCollected,
            todayCollected: todayCollected,
            successfulCount: successfulPayments.length,
            cancelledCount: cancelledPayments.length,
          ),
          const SizedBox(height: 24),
          _PaymentFilters(
            searchController: _searchController,
            selectedStatus: _selectedStatus,
            selectedMethod: _selectedMethod,
            hasFilters: hasFilters,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onStatusChanged: (value) {
              setState(() {
                _selectedStatus = value ?? 'ALL';
              });
            },
            onMethodChanged: (value) {
              setState(() {
                _selectedMethod = value ?? 'ALL';
              });
            },
            onClear: _clearFilters,
          ),
          const SizedBox(height: 18),
          _PaymentResultBar(
            visibleCount: filteredPayments.length,
            totalCount: payments.length,
          ),
          const SizedBox(height: 14),
          if (payments.isEmpty)
            _EmptyPayments(
              canRecord: canRecord,
              hasFilters: false,
              onRecordPayment: _recordPayment,
              onClearFilters: _clearFilters,
            )
          else if (filteredPayments.isEmpty)
            _EmptyPayments(
              canRecord: canRecord,
              hasFilters: true,
              onRecordPayment: _recordPayment,
              onClearFilters: _clearFilters,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 920) {
                  return _PaymentsTable(
                    payments: filteredPayments,
                    onView: _viewPayment,
                  );
                }

                return _PaymentsCardList(
                  payments: filteredPayments,
                  onView: _viewPayment,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({
    required this.canRecord,
    required this.onRecordPayment,
    required this.onRefresh,
  });

  final bool canRecord;
  final VoidCallback onRecordPayment;
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
                color: AppColors.success.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppColors.success,
                size: 29,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payments',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track invoice collections, payment methods and balances.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            if (canRecord) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onRecordPayment,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Record Payment'),
              ),
            ],
          ],
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actions,
              ),
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

class _PaymentSummaryGrid extends StatelessWidget {
  const _PaymentSummaryGrid({
    required this.totalCollected,
    required this.todayCollected,
    required this.successfulCount,
    required this.cancelledCount,
  });

  final double totalCollected;
  final double todayCollected;
  final int successfulCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PaymentSummaryCard(
        title: 'Total Collected',
        value: _money(totalCollected),
        subtitle: 'Successful payments',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
      ),
      _PaymentSummaryCard(
        title: 'Collected Today',
        value: _money(todayCollected),
        subtitle: 'Today’s successful collection',
        icon: Icons.today_rounded,
        color: AppColors.primary,
      ),
      _PaymentSummaryCard(
        title: 'Successful',
        value: successfulCount.toString(),
        subtitle: 'Valid payment records',
        icon: Icons.verified_rounded,
        color: AppColors.success,
      ),
      _PaymentSummaryCard(
        title: 'Cancelled',
        value: cancelledCount.toString(),
        subtitle: 'Reversed payment records',
        icon: Icons.money_off_csred_rounded,
        color: AppColors.danger,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1150
            ? 4
            : width >= 650
            ? 2
            : 1;

        const spacing = 16.0;

        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentFilters extends StatelessWidget {
  const _PaymentFilters({
    required this.searchController,
    required this.selectedStatus,
    required this.selectedMethod,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onMethodChanged,
    required this.onClear,
  });

  final TextEditingController searchController;

  final String selectedStatus;
  final String selectedMethod;

  final bool hasFilters;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onMethodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Search payments',
              hintText: 'Payment code, invoice ID or reference',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );

          final status = DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
              DropdownMenuItem(value: 'SUCCESS', child: Text('Successful')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
            onChanged: onStatusChanged,
          );

          final method = DropdownButtonFormField<String>(
            initialValue: selectedMethod,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Payment method',
              prefixIcon: Icon(Icons.wallet_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All methods')),
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
              DropdownMenuItem(
                value: 'BANK_TRANSFER',
                child: Text('Bank Transfer'),
              ),
            ],
            onChanged: onMethodChanged,
          );

          final clearButton = OutlinedButton.icon(
            onPressed: hasFilters ? onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Clear'),
          );

          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                search,
                const SizedBox(height: 14),
                status,
                const SizedBox(height: 14),
                method,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: clearButton),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 14),
              Expanded(child: status),
              const SizedBox(width: 14),
              Expanded(child: method),
              const SizedBox(width: 14),
              SizedBox(height: 56, child: clearButton),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentResultBar extends StatelessWidget {
  const _PaymentResultBar({
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
          '$visibleCount of $totalCount payments',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        const Icon(
          Icons.info_outline_rounded,
          size: 17,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        const Flexible(
          child: Text(
            'Only successful payments count toward revenue.',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.payments, required this.onView});

  final List<Payment> payments;
  final ValueChanged<Payment> onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
                    AppColors.primary.withValues(alpha: 0.055),
                  ),
                  horizontalMargin: 22,
                  columnSpacing: 30,
                  columns: const [
                    DataColumn(label: Text('Payment')),
                    DataColumn(label: Text('Invoice')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Paid At')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: payments.map((payment) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.paymentCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (payment.transactionReference != null)
                                Text(
                                  payment.transactionReference!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(Text('#${payment.invoiceId}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _paymentMethodIcon(payment.paymentMethod),
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(payment.formattedMethod),
                            ],
                          ),
                        ),
                        DataCell(Text(_formatDateTime(payment.paidAt))),
                        DataCell(
                          Text(
                            _money(payment.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: payment.isCancelled
                                  ? AppColors.danger
                                  : AppColors.success,
                              decoration: payment.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        DataCell(_PaymentStatusBadge(status: payment.status)),
                        DataCell(
                          IconButton(
                            tooltip: 'View payment',
                            onPressed: () {
                              onView(payment);
                            },
                            icon: const Icon(Icons.visibility_outlined),
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

class _PaymentsCardList extends StatelessWidget {
  const _PaymentsCardList({required this.payments, required this.onView});

  final List<Payment> payments;
  final ValueChanged<Payment> onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: payments.map((payment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              onView(payment);
            },
            child: Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: payment.isCancelled
                              ? AppColors.danger.withValues(alpha: 0.09)
                              : AppColors.success.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _paymentMethodIcon(payment.paymentMethod),
                          color: payment.isCancelled
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.paymentCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Invoice #${payment.invoiceId}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PaymentStatusBadge(status: payment.status),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentCardInfo(
                          label: 'Method',
                          value: payment.formattedMethod,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PaymentCardInfo(
                          label: 'Paid at',
                          value: _formatDateTime(payment.paidAt),
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _money(payment.amount),
                        style: TextStyle(
                          color: payment.isCancelled
                              ? AppColors.danger
                              : AppColors.success,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          decoration: payment.isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentCardInfo extends StatelessWidget {
  const _PaymentCardInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();

    final isCancelled = normalized == 'CANCELLED';

    final color = isCancelled ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        isCancelled ? 'Cancelled' : 'Successful',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments({
    required this.canRecord,
    required this.hasFilters,
    required this.onRecordPayment,
    required this.onClearFilters,
  });

  final bool canRecord;
  final bool hasFilters;

  final VoidCallback onRecordPayment;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters ? Icons.search_off_rounded : Icons.payments_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilters ? 'No matching payments' : 'No payment recorded yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters
                ? 'Change or clear the current filters.'
                : 'Recorded invoice payments will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (hasFilters)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear Filters'),
            )
          else if (canRecord)
            FilledButton.icon(
              onPressed: onRecordPayment,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Record Payment'),
            ),
        ],
      ),
    );
  }
}

class _PaymentsLoading extends StatelessWidget {
  const _PaymentsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            4,
            (index) => Container(
              width: 250,
              height: 118,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Text(
              'Loading payments...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentsError extends StatelessWidget {
  const _PaymentsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.danger,
            size: 44,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load payments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message
                .replaceFirst('Exception: ', '')
                .replaceFirst('ApiException: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
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

bool _isToday(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();

  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

String _money(double value) {
  return '₹${value.toStringAsFixed(2)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');

  final hour = local.hour > 12
      ? local.hour - 12
      : local.hour == 0
      ? 12
      : local.hour;

  final minute = local.minute.toString().padLeft(2, '0');

  final period = local.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/${local.year} '
      '${hour.toString().padLeft(2, '0')}:'
      '$minute $period';
}
