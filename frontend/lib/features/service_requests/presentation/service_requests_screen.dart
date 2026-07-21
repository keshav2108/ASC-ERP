import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../dashboard/data/dashboard_provider.dart';
import '../../job_cards/data/job_card_model.dart';
import '../data/service_request_model.dart';
import '../data/service_request_provider.dart';
import 'register_complaint_dialog.dart';
import 'service_request_form_dialog.dart';
import 'widgets/assign_technician_dialog.dart';

class ServiceRequestsScreen extends ConsumerStatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  ConsumerState<ServiceRequestsScreen> createState() =>
      _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends ConsumerState<ServiceRequestsScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createRequest() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return RegisterComplaintDialog(
          onRegister: (input) async {
            await ref
                .read(serviceRequestProvider.notifier)
                .registerComplaint(input);
          },
        );
      },
    );

    if (saved == true && mounted) {
      ref.invalidate(dashboardProvider);

      _showMessage('Customer complaint registered successfully.');
    }
  }

  Future<void> _editRequest(ServiceRequest request) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ServiceRequestFormDialog.edit(
          serviceRequest: request,
          onUpdate: (input) async {
            await ref
                .read(serviceRequestProvider.notifier)
                .editRequest(request.id, input);
          },
        );
      },
    );

    if (saved == true && mounted) {
      ref.invalidate(dashboardProvider);

      _showMessage('Service request updated successfully.');
    }
  }

  Future<void> _assignTechnician(ServiceRequest request) async {
    if (!_canManageServiceRequests(context)) {
      _showMessage(
        'Only Admin or Service Manager can assign technicians.',
        isError: true,
      );

      return;
    }

    if (!_canAssignTechnician(request)) {
      _showMessage(
        'A technician can only be assigned to an open request.',
        isError: true,
      );
      return;
    }

    final jobCard = await showDialog<JobCard>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AssignTechnicianDialog(serviceRequest: request);
      },
    );

    if (jobCard == null || !mounted) {
      return;
    }

    _showMessage(
      'Technician assigned successfully. '
      'Job card ${jobCard.jobCode} created.',
    );
  }

  Future<void> _cancelRequest(ServiceRequest request) async {
    if (!_canManageServiceRequests(context)) {
      _showMessage(
        'Only Admin or Service Manager can cancel requests.',
        isError: true,
      );

      return;
    }

    final status = request.status.toUpperCase();

    if (status == 'CANCELLED') {
      _showMessage('This service request is already cancelled.', isError: true);
      return;
    }

    if (status == 'DELIVERED') {
      _showMessage(
        'A delivered service request cannot be cancelled.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel service request?'),
          content: Text(
            '${request.requestCode} for '
            '${request.customer.fullName} will be marked '
            'as cancelled. Existing records will remain saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Keep Request'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Cancel Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(serviceRequestProvider.notifier).cancelRequest(request.id);

      ref.invalidate(dashboardProvider);

      if (mounted) {
        _showMessage('Service request cancelled successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error), isError: true);
      }
    }
  }

  void _showDetails(ServiceRequest request) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ServiceRequestDetailsDialog(
          request: request,
          onEdit: () {
            Navigator.of(dialogContext).pop();

            _editRequest(request);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();

            _cancelRequest(request);
          },
        );
      },
    );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedStatus = 'ALL';
      _selectedPriority = 'ALL';
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
    final requestState = ref.watch(serviceRequestProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;

        return RefreshIndicator(
          onRefresh: () {
            return ref.read(serviceRequestProvider.notifier).refreshRequests();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            children: [
              _ServiceRequestsHeader(
                onCreate: _createRequest,
                onRefresh: () {
                  ref.read(serviceRequestProvider.notifier).refreshRequests();
                },
              ),
              const SizedBox(height: 20),
              requestState.when(
                data: (requests) {
                  return _buildRequestContent(requests, constraints.maxWidth);
                },
                loading: () => const _LoadingRequests(),
                error: (error, stackTrace) {
                  return _RequestsError(
                    message: _cleanError(error),
                    onRetry: () {
                      ref
                          .read(serviceRequestProvider.notifier)
                          .refreshRequests();
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

  Widget _buildRequestContent(
    List<ServiceRequest> requests,
    double availableWidth,
  ) {
    final statuses =
        requests
            .map((request) => request.status)
            .where((status) => status.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final priorities =
        requests
            .map((request) => request.priority)
            .where((priority) => priority.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final filteredRequests = requests.where((request) {
      final searchableValues = [
        request.requestCode,
        request.customer.customerCode,
        request.customer.fullName,
        request.customer.mobile,
        request.customerProduct.brand,
        request.customerProduct.productName,
        request.customerProduct.modelNumber ?? '',
        request.customerProduct.serialNumber ?? '',
        request.complaintCategory,
        request.complaintDescription,
        request.priority,
        request.status,
      ].join(' ').toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty || searchableValues.contains(_searchQuery);

      final matchesStatus =
          _selectedStatus == 'ALL' || request.status == _selectedStatus;

      final matchesPriority =
          _selectedPriority == 'ALL' || request.priority == _selectedPriority;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequestFilters(
          searchController: _searchController,
          statuses: statuses,
          priorities: priorities,
          selectedStatus: _selectedStatus,
          selectedPriority: _selectedPriority,
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
          onStatusChanged: (value) {
            setState(() {
              _selectedStatus = value ?? 'ALL';
            });
          },
          onPriorityChanged: (value) {
            setState(() {
              _selectedPriority = value ?? 'ALL';
            });
          },
          onClear: _clearFilters,
        ),
        const SizedBox(height: 18),
        _RequestCountBar(
          visibleCount: filteredRequests.length,
          totalCount: requests.length,
        ),
        const SizedBox(height: 14),
        if (filteredRequests.isEmpty)
          _EmptyRequests(
            hasFilters:
                _searchQuery.isNotEmpty ||
                _selectedStatus != 'ALL' ||
                _selectedPriority != 'ALL',
            onCreate: _createRequest,
            onClearFilters: _clearFilters,
          )
        else if (availableWidth >= 1050)
          _ServiceRequestsTable(
            requests: filteredRequests,
            onAssign: _assignTechnician,
            onView: _showDetails,
            onEdit: _editRequest,
            onCancel: _cancelRequest,
          )
        else
          _ServiceRequestsCardList(
            requests: filteredRequests,
            onAssign: _assignTechnician,
            onView: _showDetails,
            onEdit: _editRequest,
            onCancel: _cancelRequest,
          ),
      ],
    );
  }
}

bool _canAssignTechnician(ServiceRequest request) {
  return request.status.trim().toUpperCase() == 'OPEN';
}

bool _canManageServiceRequests(BuildContext context) {
  final authState = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(authProvider);

  return AppPermissions.canManageServiceRequests(
    AppRoles.fromUser(authState.user),
  );
}

class _ServiceRequestsHeader extends StatelessWidget {
  const _ServiceRequestsHeader({
    required this.onCreate,
    required this.onRefresh,
  });

  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heading = Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.build_circle_rounded,
                    color: AppColors.primary,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Requests',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage customer complaints and service workflow.',
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
                  tooltip: 'Refresh service requests',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Create Request'),
                ),
              ],
            );

            if (constraints.maxWidth < 650) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 20), actions],
              );
            }

            return Row(
              children: [
                Expanded(child: heading),
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

class _RequestFilters extends StatelessWidget {
  const _RequestFilters({
    required this.searchController,
    required this.statuses,
    required this.priorities,
    required this.selectedStatus,
    required this.selectedPriority,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final List<String> statuses;
  final List<String> priorities;
  final String selectedStatus;
  final String selectedPriority;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final VoidCallback onClear;

  bool get hasFilters =>
      searchController.text.isNotEmpty ||
      selectedStatus != 'ALL' ||
      selectedPriority != 'ALL';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search request, customer, product or complaint',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            );

            final statusField = DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.change_circle_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('All statuses'),
                ),
                ...statuses.map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(
                      _formatStatus(status),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onStatusChanged,
            );

            final priorityField = DropdownButtonFormField<String>(
              initialValue: selectedPriority,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.priority_high_rounded),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('All priorities'),
                ),
                ...priorities.map(
                  (priority) => DropdownMenuItem(
                    value: priority,
                    child: Text(
                      _formatStatus(priority),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onPriorityChanged,
            );

            final clearButton = OutlinedButton.icon(
              onPressed: hasFilters ? onClear : null,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Clear'),
            );

            if (constraints.maxWidth < 850) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: statusField),
                      const SizedBox(width: 12),
                      Expanded(child: priorityField),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: clearButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 14),
                Expanded(child: statusField),
                const SizedBox(width: 14),
                Expanded(child: priorityField),
                const SizedBox(width: 14),
                clearButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestCountBar extends StatelessWidget {
  const _RequestCountBar({
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
          '$visibleCount service request'
          '${visibleCount == 1 ? '' : 's'}',
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

class _ServiceRequestsTable extends StatelessWidget {
  const _ServiceRequestsTable({
    required this.requests,
    required this.onAssign,
    required this.onView,
    required this.onEdit,
    required this.onCancel,
  });

  final List<ServiceRequest> requests;
  final ValueChanged<ServiceRequest> onAssign;
  final ValueChanged<ServiceRequest> onView;
  final ValueChanged<ServiceRequest> onEdit;
  final ValueChanged<ServiceRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: 22,
                columnSpacing: 30,
                columns: const [
                  DataColumn(label: Text('Request')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Complaint')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: requests.map((request) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          request.requestCode,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.customer.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                request.customer.mobile,
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
                        SizedBox(
                          width: 180,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.customerProduct.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatStatus(
                                  request.customerProduct.warrantyStatus,
                                ),
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
                        SizedBox(
                          width: 155,
                          child: Text(
                            _formatStatus(request.complaintCategory),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_PriorityBadge(priority: request.priority)),
                      DataCell(_StatusBadge(status: request.status)),
                      DataCell(Text(_formatDate(request.createdAt))),
                      DataCell(
                        _RequestActions(
                          request: request,
                          onAssign: onAssign,
                          onView: onView,
                          onEdit: onEdit,
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
    );
  }
}

class _ServiceRequestsCardList extends StatelessWidget {
  const _ServiceRequestsCardList({
    required this.requests,
    required this.onAssign,
    required this.onView,
    required this.onEdit,
    required this.onCancel,
  });

  final List<ServiceRequest> requests;
  final ValueChanged<ServiceRequest> onAssign;
  final ValueChanged<ServiceRequest> onView;
  final ValueChanged<ServiceRequest> onEdit;
  final ValueChanged<ServiceRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: requests.map((request) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onView(request),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.home_repair_service_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.requestCode,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatDateTime(request.createdAt),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      request.customer.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.customer.mobile} • '
                      '${request.customer.customerCode}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    _InformationRow(
                      icon: Icons.devices_other_outlined,
                      value: request.customerProduct.displayName,
                    ),
                    const SizedBox(height: 8),
                    _InformationRow(
                      icon: Icons.category_outlined,
                      value: _formatStatus(request.complaintCategory),
                    ),
                    const SizedBox(height: 8),
                    _InformationRow(
                      icon: Icons.description_outlined,
                      value: request.complaintDescription,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PriorityBadge(priority: request.priority),
                        _WarrantyBadge(
                          warrantyStatus:
                              request.customerProduct.warrantyStatus,
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_canManageServiceRequests(context) &&
                            _canAssignTechnician(request))
                          IconButton(
                            onPressed: () {
                              onAssign(request);
                            },
                            tooltip: 'Assign technician',
                            color: AppColors.primary,
                            icon: const Icon(Icons.assignment_ind_rounded),
                          ),
                        TextButton.icon(
                          onPressed: () {
                            onView(request);
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            onEdit(request);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        if (_canManageServiceRequests(context))
                          IconButton(
                            onPressed: _canCancel(request)
                                ? () {
                                    onCancel(request);
                                  }
                                : null,
                            tooltip: 'Cancel request',
                            color: AppColors.danger,
                            icon: const Icon(Icons.cancel_outlined),
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

class _RequestActions extends StatelessWidget {
  const _RequestActions({
    required this.request,
    required this.onAssign,
    required this.onView,
    required this.onEdit,
    required this.onCancel,
  });

  final ServiceRequest request;
  final ValueChanged<ServiceRequest> onAssign;
  final ValueChanged<ServiceRequest> onView;
  final ValueChanged<ServiceRequest> onEdit;
  final ValueChanged<ServiceRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canManageServiceRequests(context) && _canAssignTechnician(request))
          IconButton(
            onPressed: () {
              onAssign(request);
            },
            tooltip: 'Assign technician',
            color: AppColors.primary,
            icon: const Icon(Icons.assignment_ind_rounded),
          ),
        IconButton(
          onPressed: () {
            onView(request);
          },
          tooltip: 'View request',
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          onPressed: () {
            onEdit(request);
          },
          tooltip: 'Edit request',
          icon: const Icon(Icons.edit_outlined),
        ),
        if (_canManageServiceRequests(context))
          IconButton(
            onPressed: _canCancel(request)
                ? () {
                    onCancel(request);
                  }
                : null,
            tooltip: 'Cancel request',
            color: AppColors.danger,
            icon: const Icon(Icons.cancel_outlined),
          ),
      ],
    );
  }
}

class _ServiceRequestDetailsDialog extends StatelessWidget {
  const _ServiceRequestDetailsDialog({
    required this.request,
    required this.onEdit,
    required this.onCancel,
  });

  final ServiceRequest request;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.home_repair_service_rounded,
                      color: AppColors.primary,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.requestCode,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Created '
                          '${_formatDateTime(request.createdAt)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: request.status),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _DetailsSection(
                title: 'Customer',
                icon: Icons.person_outline_rounded,
                children: [
                  _DetailsRow(label: 'Name', value: request.customer.fullName),
                  _DetailsRow(
                    label: 'Customer code',
                    value: request.customer.customerCode,
                  ),
                  _DetailsRow(label: 'Mobile', value: request.customer.mobile),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Product',
                icon: Icons.devices_other_outlined,
                children: [
                  _DetailsRow(
                    label: 'Brand',
                    value: request.customerProduct.brand,
                  ),
                  _DetailsRow(
                    label: 'Product',
                    value: request.customerProduct.productName,
                  ),
                  _DetailsRow(
                    label: 'Model number',
                    value: request.customerProduct.modelNumber ?? '—',
                  ),
                  _DetailsRow(
                    label: 'Serial number',
                    value: request.customerProduct.serialNumber ?? '—',
                  ),
                  _DetailsRow(
                    label: 'Warranty',
                    value: _formatStatus(
                      request.customerProduct.warrantyStatus,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Complaint',
                icon: Icons.description_outlined,
                children: [
                  _DetailsRow(
                    label: 'Category',
                    value: _formatStatus(request.complaintCategory),
                  ),
                  _DetailsRow(
                    label: 'Description',
                    value: request.complaintDescription,
                  ),
                  _DetailsRow(
                    label: 'Accessories',
                    value: request.receivedAccessories ?? '—',
                  ),
                  _DetailsRow(
                    label: 'Product condition',
                    value: _formatStatus(request.productCondition),
                  ),
                  _DetailsRow(
                    label: 'Priority',
                    value: _formatStatus(request.priority),
                  ),
                  _DetailsRow(
                    label: 'Status',
                    value: _formatStatus(request.status),
                  ),
                  _DetailsRow(
                    label: 'Estimated delivery',
                    value: request.estimatedDelivery == null
                        ? '—'
                        : _formatDateTime(request.estimatedDelivery!),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                  if (_canManageServiceRequests(context) &&
                      _canCancel(request)) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Request'),
                    ),
                  ],
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Request'),
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

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 21),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          ...children,
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
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

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_formatStatus(priority)} priority',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WarrantyBadge extends StatelessWidget {
  const _WarrantyBadge({required this.warrantyStatus});

  final String warrantyStatus;

  @override
  Widget build(BuildContext context) {
    final normalized = warrantyStatus.toUpperCase();

    final color = normalized == 'IN' || normalized == 'IN_WARRANTY'
        ? AppColors.success
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatStatus(warrantyStatus),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({
    required this.hasFilters,
    required this.onCreate,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onCreate;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 340,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.home_repair_service_outlined,
                  size: 60,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  hasFilters
                      ? 'No matching service requests'
                      : 'No service requests yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  hasFilters
                      ? 'Change or clear the current search filters.'
                      : 'Create the first customer complaint to begin.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 22),
                if (hasFilters)
                  OutlinedButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Clear Filters'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Create Request'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingRequests extends StatelessWidget {
  const _LoadingRequests();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text(
                'Loading service requests...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsError extends StatelessWidget {
  const _RequestsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 350,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.danger,
                  size: 55,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load service requests',
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

bool _canCancel(ServiceRequest request) {
  final status = request.status.toUpperCase();

  return status != 'CANCELLED' && status != 'DELIVERED';
}

String _formatStatus(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) =>
            '${word[0].toUpperCase()}'
            '${word.substring(1)}',
      )
      .join(' ');
}

String _formatDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');

  return '$day/$month/${dateTime.year}';
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$day/$month/${dateTime.year} '
      '$hour:$minute';
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'OPEN':
    case 'PENDING':
    case 'WAITING_PARTS':
      return AppColors.warning;

    case 'ASSIGNED':
    case 'ACCEPTED':
    case 'DIAGNOSIS':
    case 'REPAIR_IN_PROGRESS':
    case 'TESTING':
      return AppColors.primary;

    case 'COMPLETED':
    case 'DELIVERED':
    case 'READY_FOR_DELIVERY':
      return AppColors.success;

    case 'CANCELLED':
    case 'REJECTED':
      return AppColors.danger;

    default:
      return AppColors.info;
  }
}

Color _priorityColor(String priority) {
  switch (priority.toUpperCase()) {
    case 'URGENT':
    case 'CRITICAL':
    case 'HIGH':
      return AppColors.danger;

    case 'NORMAL':
    case 'MEDIUM':
      return AppColors.warning;

    case 'LOW':
      return AppColors.success;

    default:
      return AppColors.info;
  }
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
