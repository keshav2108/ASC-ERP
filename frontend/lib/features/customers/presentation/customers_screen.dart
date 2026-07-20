import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/data/dashboard_provider.dart';
import '../data/customer_model.dart';
import '../data/customer_provider.dart';
import 'customer_form_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addCustomer() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CustomerFormDialog(
          onSubmit: (input) async {
            await ref.read(customerProvider.notifier).addCustomer(input);
          },
        );
      },
    );

    if (saved == true && mounted) {
      ref.invalidate(dashboardProvider);
      _showMessage('Customer added successfully.');
    }
  }

  Future<void> _editCustomer(Customer customer) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CustomerFormDialog(
          customer: customer,
          onSubmit: (input) async {
            await ref
                .read(customerProvider.notifier)
                .editCustomer(customer.id, input);
          },
        );
      },
    );

    if (saved == true && mounted) {
      ref.invalidate(dashboardProvider);
      _showMessage('Customer updated successfully.');
    }
  }

  Future<void> _deactivateCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate customer?'),
          content: Text(
            '${customer.fullName} will be removed from the active '
            'customer list. Existing records will remain saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(customerProvider.notifier).deactivateCustomer(customer.id);

      ref.invalidate(dashboardProvider);

      if (mounted) {
        _showMessage('Customer deactivated successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error), isError: true);
      }
    }
  }

  void _showDetails(Customer customer) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _CustomerDetailsDialog(
          customer: customer,
          onEdit: () {
            Navigator.of(context).pop();
            _editCustomer(customer);
          },
        );
      },
    );
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
    final customerState = ref.watch(customerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;

        return RefreshIndicator(
          onRefresh: () {
            return ref.read(customerProvider.notifier).refreshCustomers();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            children: [
              _CustomersHeader(
                onAdd: _addCustomer,
                onRefresh: () {
                  ref.read(customerProvider.notifier).refreshCustomers();
                },
              ),
              const SizedBox(height: 20),
              _SearchCard(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                onClear: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
              const SizedBox(height: 20),
              customerState.when(
                data: (customers) {
                  final filteredCustomers = customers.where((customer) {
                    if (_searchQuery.isEmpty) {
                      return true;
                    }

                    final values = [
                      customer.customerCode,
                      customer.fullName,
                      customer.mobile,
                      customer.alternateMobile ?? '',
                      customer.email ?? '',
                      customer.city ?? '',
                    ].join(' ').toLowerCase();

                    return values.contains(_searchQuery);
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CustomerCountBar(
                        visibleCount: filteredCustomers.length,
                        totalCount: customers.length,
                      ),
                      const SizedBox(height: 14),
                      if (filteredCustomers.isEmpty)
                        _EmptyCustomers(
                          hasSearch: _searchQuery.isNotEmpty,
                          onAdd: _addCustomer,
                        )
                      else if (constraints.maxWidth >= 900)
                        _CustomersTable(
                          customers: filteredCustomers,
                          onView: _showDetails,
                          onEdit: _editCustomer,
                          onDeactivate: _deactivateCustomer,
                        )
                      else
                        _CustomersCardList(
                          customers: filteredCustomers,
                          onView: _showDetails,
                          onEdit: _editCustomer,
                          onDeactivate: _deactivateCustomer,
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 350,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) {
                  return _CustomersError(
                    message: _cleanError(error),
                    onRetry: () {
                      ref.read(customerProvider.notifier).refreshCustomers();
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
}

class _CustomersHeader extends StatelessWidget {
  const _CustomersHeader({required this.onAdd, required this.onRefresh});

  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
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
                    Icons.people_alt_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customers',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage registered ASC customers.',
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
                IconButton.outlined(
                  onPressed: onRefresh,
                  tooltip: 'Refresh customers',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add Customer'),
                ),
              ],
            );

            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 20), actions],
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
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search by name, mobile, customer code, email or city',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CustomerCountBar extends StatelessWidget {
  const _CustomerCountBar({
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
          '$visibleCount customer${visibleCount == 1 ? '' : 's'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (visibleCount != totalCount) ...[
          const SizedBox(width: 8),
          Text(
            'of $totalCount',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _CustomersTable extends StatelessWidget {
  const _CustomersTable({
    required this.customers,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 32,
          horizontalMargin: 22,
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Mobile')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: customers.map((customer) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    customer.customerCode,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (customer.email != null)
                          Text(
                            customer.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(customer.mobile)),
                DataCell(Text(customer.city ?? '—')),
                DataCell(Text(_formatDate(customer.createdAt))),
                DataCell(_StatusBadge(status: customer.status)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => onView(customer),
                        tooltip: 'View customer',
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                      IconButton(
                        onPressed: () => onEdit(customer),
                        tooltip: 'Edit customer',
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => onDeactivate(customer),
                        tooltip: 'Deactivate customer',
                        color: AppColors.danger,
                        icon: const Icon(Icons.person_off_outlined),
                      ),
                    ],
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

class _CustomersCardList extends StatelessWidget {
  const _CustomersCardList({
    required this.customers,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: customers.map((customer) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onView(customer),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            customer.fullName.isEmpty
                                ? 'C'
                                : customer.fullName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                customer.customerCode,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: customer.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      value: customer.mobile,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.location_city_outlined,
                      value: customer.city ?? 'City not provided',
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => onView(customer),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View'),
                        ),
                        TextButton.icon(
                          onPressed: () => onEdit(customer),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        IconButton(
                          onPressed: () => onDeactivate(customer),
                          tooltip: 'Deactivate',
                          color: AppColors.danger,
                          icon: const Icon(Icons.person_off_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomerDetailsDialog extends StatelessWidget {
  const _CustomerDetailsDialog({required this.customer, required this.onEdit});

  final Customer customer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(customer.fullName)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _DialogDetail(
                label: 'Customer code',
                value: customer.customerCode,
              ),
              _DialogDetail(label: 'Mobile', value: customer.mobile),
              _DialogDetail(
                label: 'Alternate mobile',
                value: customer.alternateMobile ?? '—',
              ),
              _DialogDetail(label: 'Email', value: customer.email ?? '—'),
              _DialogDetail(label: 'Address', value: customer.address ?? '—'),
              _DialogDetail(label: 'City', value: customer.city ?? '—'),
              _DialogDetail(label: 'Pincode', value: customer.pincode ?? '—'),
              _DialogDetail(
                label: 'Registered',
                value: _formatDate(customer.createdAt),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Edit Customer'),
        ),
      ],
    );
  }
}

class _DialogDetail extends StatelessWidget {
  const _DialogDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status.toUpperCase() == 'ACTIVE';
    final color = active ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.hasSearch, required this.onAdd});

  final bool hasSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 330,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 58,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                hasSearch
                    ? 'No matching customers found'
                    : 'No customers registered yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                hasSearch
                    ? 'Try another name, mobile number or code.'
                    : 'Add your first ASC customer to get started.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (!hasSearch) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add Customer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomersError extends StatelessWidget {
  const _CustomersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 330,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.danger,
                  size: 54,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load customers',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
