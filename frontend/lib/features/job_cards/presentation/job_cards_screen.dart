import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../notifications/data/notification_navigation_provider.dart';
import '../../technicians/data/technician_provider.dart';
import '../data/job_card_model.dart';
import '../data/job_card_provider.dart';
import 'job_card_edit_dialog.dart';

import 'job_card_workflow_dialog.dart';

class JobCardsScreen extends ConsumerStatefulWidget {
  const JobCardsScreen({super.key});

  @override
  ConsumerState<JobCardsScreen> createState() => _JobCardsScreenState();
}

class _JobCardsScreenState extends ConsumerState<JobCardsScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  int _selectedTechnicianId = 0;
  bool _isOpeningNotificationJobCard = false;

  String get _currentUserRole {
    return AppRoles.fromUser(ref.read(authProvider).user);
  }

  bool get _canManageJobCards {
    return AppPermissions.canManageJobCards(_currentUserRole);
  }

  bool get _canRunWorkflow {
    return AppPermissions.canRunJobCardWorkflow(_currentUserRole);
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
      _selectedStatus = 'ALL';
      _selectedTechnicianId = 0;
    });
  }

  void _showJobCardDetails(JobCard jobCard) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _JobCardDetailsDialog(jobCard: jobCard);
      },
    );
  }

  Future<void> _openNotificationJobCard(int jobCardId) async {
    if (_isOpeningNotificationJobCard) {
      return;
    }

    _isOpeningNotificationJobCard = true;

    ref.read(pendingNotificationJobCardIdProvider.notifier).state = null;

    try {
      final cachedJobCards =
          ref.read(jobCardProvider).value ?? const <JobCard>[];

      JobCard? linkedJobCard;

      for (final jobCard in cachedJobCards) {
        if (jobCard.id == jobCardId) {
          linkedJobCard = jobCard;
          break;
        }
      }

      linkedJobCard ??= await ref
          .read(jobCardServiceProvider)
          .getJobCard(jobCardId);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _JobCardDetailsDialog(jobCard: linkedJobCard!);
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to open linked Job Card: '
        '${_cleanError(error)}',
        isError: true,
      );
    } finally {
      _isOpeningNotificationJobCard = false;
    }
  }

  Future<void> _editJobCard(JobCard jobCard) async {
    if (!_canManageJobCards) {
      _showMessage(
        'Only Admin or Service Manager can edit job cards.',
        isError: true,
      );

      return;
    }

    if (jobCard.isClosed) {
      _showMessage(
        'Delivered or cancelled job cards cannot be edited.',
        isError: true,
      );
      return;
    }

    final updatedJobCard = await showDialog<JobCard>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return JobCardEditDialog(jobCard: jobCard);
      },
    );

    if (updatedJobCard == null || !mounted) {
      return;
    }

    _showMessage('${updatedJobCard.jobCode} updated successfully.');
  }

  Future<void> _manageWorkflow(JobCard jobCard) async {
    if (!_canRunWorkflow) {
      _showMessage(
        'You do not have permission to manage job card workflow.',
        isError: true,
      );

      return;
    }

    await showDialog<JobCard>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return JobCardWorkflowDialog(jobCard: jobCard);
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
    final jobCardsState = ref.watch(jobCardProvider);
    ref.listen<int?>(pendingNotificationJobCardIdProvider, (
      previousJobCardId,
      nextJobCardId,
    ) {
      if (nextJobCardId == null ||
          nextJobCardId == previousJobCardId ||
          _isOpeningNotificationJobCard) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _openNotificationJobCard(nextJobCardId);
      });
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;

        return RefreshIndicator(
          onRefresh: () {
            return ref.read(jobCardProvider.notifier).refreshJobCards();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            children: [
              _JobCardsHeader(
                onRefresh: () {
                  ref.read(jobCardProvider.notifier).refreshJobCards();
                },
              ),
              const SizedBox(height: 20),
              jobCardsState.when(
                data: (jobCards) {
                  return _buildJobCardContent(jobCards, constraints.maxWidth);
                },
                loading: () => const _LoadingJobCards(),
                error: (error, stackTrace) {
                  return _JobCardsError(
                    message: _cleanError(error),
                    onRetry: () {
                      ref.read(jobCardProvider.notifier).refreshJobCards();
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

  Widget _buildJobCardContent(List<JobCard> jobCards, double availableWidth) {
    final statuses =
        jobCards
            .map((jobCard) => jobCard.status)
            .where((status) => status.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final techniciansState = ref.watch(technicianProvider);
    final technicians = <int, String>{};

    for (final technician in techniciansState.value ?? []) {
      if (!technician.isActive) {
        continue;
      }

      technicians[technician.id] =
          '${technician.fullName} '
          '(${technician.technicianCode})';
    }

    // Keep historical technicians available for filtering even when
    // they are no longer active.
    for (final jobCard in jobCards) {
      technicians.putIfAbsent(
        jobCard.technician.id,
        () =>
            '${jobCard.technician.fullName} '
            '(${jobCard.technician.technicianCode})',
      );
    }

    final technicianEntries = technicians.entries.toList()
      ..sort(
        (first, second) =>
            first.value.toLowerCase().compareTo(second.value.toLowerCase()),
      );

    final filteredJobCards = jobCards.where((jobCard) {
      final searchableValues = [
        jobCard.jobCode,
        jobCard.serviceRequest.requestCode,
        jobCard.technician.fullName,
        jobCard.technician.technicianCode,
        jobCard.technician.mobile,
        jobCard.serviceRequest.complaintCategory,
        jobCard.serviceRequest.complaintDescription,
        jobCard.serviceRequest.priority,
        jobCard.status,
        jobCard.diagnosis ?? '',
        jobCard.repairNotes ?? '',
      ].join(' ').toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty || searchableValues.contains(_searchQuery);

      final matchesStatus =
          _selectedStatus == 'ALL' || jobCard.status == _selectedStatus;

      final matchesTechnician =
          _selectedTechnicianId == 0 ||
          jobCard.technicianId == _selectedTechnicianId;

      return matchesSearch && matchesStatus && matchesTechnician;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JobCardFilters(
          searchController: _searchController,
          statuses: statuses,
          technicians: technicianEntries,
          selectedStatus: _selectedStatus,
          selectedTechnicianId: _selectedTechnicianId,
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
          onTechnicianChanged: (value) {
            setState(() {
              _selectedTechnicianId = value ?? 0;
            });
          },
          onClear: _clearFilters,
        ),
        const SizedBox(height: 18),
        _JobCardCountBar(
          visibleCount: filteredJobCards.length,
          totalCount: jobCards.length,
        ),
        const SizedBox(height: 14),
        if (filteredJobCards.isEmpty)
          _EmptyJobCards(
            hasFilters:
                _searchQuery.isNotEmpty ||
                _selectedStatus != 'ALL' ||
                _selectedTechnicianId != 0,
            onClearFilters: _clearFilters,
          )
        else if (availableWidth >= 1050)
          _JobCardsTable(
            jobCards: filteredJobCards,
            canManage: _canManageJobCards,
            canRunWorkflow: _canRunWorkflow,
            onWorkflow: _manageWorkflow,
            onEdit: _editJobCard,
            onView: _showJobCardDetails,
          )
        else
          _JobCardsCardList(
            jobCards: filteredJobCards,
            canManage: _canManageJobCards,
            canRunWorkflow: _canRunWorkflow,
            onWorkflow: _manageWorkflow,
            onEdit: _editJobCard,
            onView: _showJobCardDetails,
          ),
      ],
    );
  }
}

class _JobCardsHeader extends StatelessWidget {
  const _JobCardsHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.assignment_rounded,
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
                    'Job Cards',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track technician assignments, repairs and delivery workflow.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              onPressed: onRefresh,
              tooltip: 'Refresh job cards',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCardFilters extends StatelessWidget {
  const _JobCardFilters({
    required this.searchController,
    required this.statuses,
    required this.technicians,
    required this.selectedStatus,
    required this.selectedTechnicianId,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onTechnicianChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final List<String> statuses;
  final List<MapEntry<int, String>> technicians;

  final String selectedStatus;
  final int selectedTechnicianId;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<int?> onTechnicianChanged;
  final VoidCallback onClear;

  bool get hasFilters {
    return searchController.text.isNotEmpty ||
        selectedStatus != 'ALL' ||
        selectedTechnicianId != 0;
  }

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
                hintText: 'Search job, request, technician or complaint',
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
                  (status) => DropdownMenuItem<String>(
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

            final technicianField = DropdownButtonFormField<int>(
              initialValue: selectedTechnicianId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Technician',
                prefixIcon: Icon(Icons.engineering_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: 0,
                  child: Text('All technicians'),
                ),
                ...technicians.map(
                  (entry) => DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: onTechnicianChanged,
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
                      Expanded(child: technicianField),
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
                Expanded(child: technicianField),
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

class _JobCardCountBar extends StatelessWidget {
  const _JobCardCountBar({
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
          '$visibleCount job card'
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

class _JobCardsTable extends StatelessWidget {
  const _JobCardsTable({
    required this.jobCards,
    required this.canManage,
    required this.canRunWorkflow,
    required this.onWorkflow,
    required this.onEdit,
    required this.onView,
  });

  final List<JobCard> jobCards;
  final bool canManage;
  final bool canRunWorkflow;

  final ValueChanged<JobCard> onWorkflow;
  final ValueChanged<JobCard> onEdit;
  final ValueChanged<JobCard> onView;

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
                  DataColumn(label: Text('Job Card')),
                  DataColumn(label: Text('Request')),
                  DataColumn(label: Text('Technician')),
                  DataColumn(label: Text('Complaint')),
                  DataColumn(label: Text('Labour')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Assigned')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: jobCards.map((jobCard) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          jobCard.jobCode,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          jobCard.serviceRequest.requestCode,
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                                jobCard.technician.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                jobCard.technician.technicianCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 190,
                          child: Text(
                            _formatStatus(
                              jobCard.serviceRequest.complaintCategory,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text('₹${jobCard.labourCharge.toStringAsFixed(2)}'),
                      ),
                      DataCell(_JobStatusBadge(status: jobCard.status)),
                      DataCell(Text(_formatDate(jobCard.assignedAt))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canRunWorkflow)
                              IconButton(
                                onPressed:
                                    jobCard.isCancelled ||
                                        (jobCard.isDelivered && !canManage)
                                    ? null
                                    : () {
                                        onWorkflow(jobCard);
                                      },
                                tooltip: jobCard.isCancelled
                                    ? 'Workflow cancelled'
                                    : jobCard.isDelivered && !canManage
                                    ? 'Only Admin or Service Manager can reverse delivery'
                                    : jobCard.isDelivered
                                    ? 'Reopen delivery workflow'
                                    : 'Manage workflow',
                                color: AppColors.primary,
                                icon: const Icon(Icons.account_tree_outlined),
                              ),
                            if (canManage)
                              IconButton(
                                onPressed: jobCard.isClosed
                                    ? null
                                    : () {
                                        onEdit(jobCard);
                                      },
                                tooltip: jobCard.isClosed
                                    ? 'Closed job card'
                                    : 'Edit job card',
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            IconButton(
                              onPressed: () {
                                onView(jobCard);
                              },
                              tooltip: 'View job card',
                              icon: const Icon(Icons.visibility_outlined),
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
        },
      ),
    );
  }
}

class _JobCardsCardList extends StatelessWidget {
  const _JobCardsCardList({
    required this.jobCards,
    required this.canManage,
    required this.canRunWorkflow,
    required this.onWorkflow,
    required this.onEdit,
    required this.onView,
  });

  final List<JobCard> jobCards;
  final bool canManage;
  final bool canRunWorkflow;

  final ValueChanged<JobCard> onWorkflow;
  final ValueChanged<JobCard> onEdit;
  final ValueChanged<JobCard> onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: jobCards.map((jobCard) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                onView(jobCard);
              },
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
                            Icons.assignment_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                jobCard.jobCode,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                jobCard.serviceRequest.requestCode,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _JobStatusBadge(status: jobCard.status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _JobInformationRow(
                      icon: Icons.engineering_outlined,
                      value:
                          '${jobCard.technician.fullName} '
                          '(${jobCard.technician.technicianCode})',
                    ),
                    const SizedBox(height: 9),
                    _JobInformationRow(
                      icon: Icons.category_outlined,
                      value: _formatStatus(
                        jobCard.serviceRequest.complaintCategory,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _JobInformationRow(
                      icon: Icons.description_outlined,
                      value: jobCard.serviceRequest.complaintDescription,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Labour: '
                          '₹${jobCard.labourCharge.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          _formatDateTime(jobCard.assignedAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (canRunWorkflow) ...[
                          TextButton.icon(
                            onPressed:
                                jobCard.isCancelled ||
                                    (jobCard.isDelivered && !canManage)
                                ? null
                                : () {
                                    onWorkflow(jobCard);
                                  },
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('Workflow'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (canManage) ...[
                          TextButton.icon(
                            onPressed: jobCard.isClosed
                                ? null
                                : () {
                                    onEdit(jobCard);
                                  },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            onView(jobCard);
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Details'),
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

class _JobInformationRow extends StatelessWidget {
  const _JobInformationRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _JobCardDetailsDialog extends StatelessWidget {
  const _JobCardDetailsDialog({required this.jobCard});

  final JobCard jobCard;

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
                      Icons.assignment_rounded,
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
                          jobCard.jobCode,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assigned '
                          '${_formatDateTime(jobCard.assignedAt)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _JobStatusBadge(status: jobCard.status),
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
              _JobDetailsSection(
                title: 'Service Request',
                children: [
                  _JobDetailsRow(
                    label: 'Request code',
                    value: jobCard.serviceRequest.requestCode,
                  ),
                  _JobDetailsRow(
                    label: 'Complaint category',
                    value: _formatStatus(
                      jobCard.serviceRequest.complaintCategory,
                    ),
                  ),
                  _JobDetailsRow(
                    label: 'Priority',
                    value: _formatStatus(jobCard.serviceRequest.priority),
                  ),
                  _JobDetailsRow(
                    label: 'Complaint',
                    value: jobCard.serviceRequest.complaintDescription,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _JobDetailsSection(
                title: 'Technician',
                children: [
                  _JobDetailsRow(
                    label: 'Name',
                    value: jobCard.technician.fullName,
                  ),
                  _JobDetailsRow(
                    label: 'Technician code',
                    value: jobCard.technician.technicianCode,
                  ),
                  _JobDetailsRow(
                    label: 'Mobile',
                    value: jobCard.technician.mobile,
                  ),
                  _JobDetailsRow(
                    label: 'Specialization',
                    value: jobCard.technician.specialization ?? 'Not specified',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _JobDetailsSection(
                title: 'Repair Information',
                children: [
                  _JobDetailsRow(
                    label: 'Diagnosis',
                    value: jobCard.diagnosis ?? 'Not added',
                  ),
                  _JobDetailsRow(
                    label: 'Repair notes',
                    value: jobCard.repairNotes ?? 'Not added',
                  ),
                  _JobDetailsRow(
                    label: 'Labour charge',
                    value: '₹${jobCard.labourCharge.toStringAsFixed(2)}',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _JobDetailsSection(
                title: 'Timeline',
                children: [
                  _JobDetailsRow(
                    label: 'Assigned',
                    value: _formatDateTime(jobCard.assignedAt),
                  ),
                  _JobDetailsRow(
                    label: 'Started',
                    value: _formatNullableDateTime(jobCard.startedAt),
                  ),
                  _JobDetailsRow(
                    label: 'Completed',
                    value: _formatNullableDateTime(jobCard.completedAt),
                  ),
                  _JobDetailsRow(
                    label: 'Delivered',
                    value: _formatNullableDateTime(jobCard.deliveredAt),
                  ),
                ],
              ),
              if (jobCard.deliveredAt != null ||
                  jobCard.deliveredTo != null ||
                  jobCard.recipientType != null ||
                  jobCard.receiverName != null ||
                  jobCard.relationToCustomer != null ||
                  jobCard.deliveryRemarks != null) ...[
                const SizedBox(height: 22),
                _JobDetailsSection(
                  title: 'Delivery Information',
                  children: [
                    _JobDetailsRow(
                      label: 'Recipient type',
                      value: jobCard.recipientType == null
                          ? 'Not recorded'
                          : jobCard.recipientType!.toUpperCase() == 'CUSTOMER'
                          ? 'Customer'
                          : 'Other Person',
                    ),
                    _JobDetailsRow(
                      label: 'Receiver name',
                      value:
                          jobCard.receiverName ??
                          jobCard.deliveredTo ??
                          'Not specified',
                    ),
                    _JobDetailsRow(
                      label: 'Relation',
                      value:
                          jobCard.relationToCustomer ??
                          (jobCard.recipientType?.toUpperCase() == 'CUSTOMER'
                              ? 'Customer / Self'
                              : 'Not recorded'),
                    ),
                    _JobDetailsRow(
                      label: 'Delivery remarks',
                      value: jobCard.deliveryRemarks ?? 'No remarks',
                    ),
                    _JobDetailsRow(
                      label: 'Delivered at',
                      value: _formatNullableDateTime(jobCard.deliveredAt),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetailsSection extends StatelessWidget {
  const _JobDetailsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _JobDetailsRow extends StatelessWidget {
  const _JobDetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
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

class _JobStatusBadge extends StatelessWidget {
  const _JobStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();

    Color color;

    switch (normalized) {
      case 'DELIVERED':
      case 'COMPLETED':
        color = AppColors.success;

      case 'CANCELLED':
        color = AppColors.danger;

      case 'WAITING_PARTS':
        color = Colors.orange;

      case 'REPAIR_IN_PROGRESS':
      case 'DIAGNOSIS':
      case 'TESTING':
        color = Colors.blue;

      default:
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingJobCards extends StatelessWidget {
  const _LoadingJobCards();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _JobCardsError extends StatelessWidget {
  const _JobCardsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 50,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load job cards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
      ),
    );
  }
}

class _EmptyJobCards extends StatelessWidget {
  const _EmptyJobCards({
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 54,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'No matching job cards' : 'No job cards created yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              hasFilters
                  ? 'Change or clear the filters to see more records.'
                  : 'Assign a technician to an open service request to create a job card.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');

  final month = dateTime.month.toString().padLeft(2, '0');

  return '$day/$month/${dateTime.year}';
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');

  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '${_formatDate(dateTime)}  '
      '$hour:$minute';
}

String _formatNullableDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Not yet';
  }

  return _formatDateTime(dateTime);
}

String _formatStatus(String value) {
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

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
