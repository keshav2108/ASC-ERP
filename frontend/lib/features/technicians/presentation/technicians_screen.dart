import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../dashboard/data/dashboard_provider.dart';
import '../data/technician_model.dart';
import '../data/technician_provider.dart';
import 'technician_form_dialog.dart';

class TechniciansScreen extends ConsumerStatefulWidget {
  const TechniciansScreen({super.key});

  @override
  ConsumerState<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends ConsumerState<TechniciansScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedAccountFilter = 'ALL';

  String get _currentUserRole {
    final role = ref
        .read(authProvider)
        .user?['role']
        ?.toString()
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    return role ?? '';
  }

  bool get _canManageTechnicians {
    return _currentUserRole == 'ADMIN' || _currentUserRole == 'SERVICE_MANAGER';
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
      _selectedAccountFilter = 'ALL';
    });
  }

  Future<void> _addTechnician() async {
    if (!_canManageTechnicians) {
      _showMessage(
        'Only Admin or Service Manager can add technicians.',
        isError: true,
      );

      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return TechnicianFormDialog.create(
          onCreate: (input) async {
            await ref.read(technicianProvider.notifier).addTechnician(input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('Technician added successfully.');
  }

  Future<void> _editTechnician(Technician technician) async {
    if (!_canManageTechnicians) {
      _showMessage(
        'Only Admin or Service Manager can edit technicians.',
        isError: true,
      );

      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return TechnicianFormDialog.edit(
          technician: technician,
          onUpdate: (input) async {
            await ref
                .read(technicianProvider.notifier)
                .editTechnician(technician.id, input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('${technician.technicianCode} updated successfully.');
  }

  Future<void> _deactivateTechnician(Technician technician) async {
    if (!_canManageTechnicians) {
      _showMessage(
        'Only Admin or Service Manager can deactivate technicians.',
        isError: true,
      );

      return;
    }

    if (!technician.isActive) {
      _showMessage('This technician is already inactive.', isError: true);

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.person_off_outlined, color: AppColors.danger),
          title: const Text('Deactivate technician?'),
          content: Text(
            '${technician.fullName} '
            '(${technician.technicianCode}) will no longer '
            'be available for new job assignments.\n\n'
            'Existing service history and job-card records '
            'will remain saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Keep Active'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(technicianProvider.notifier)
          .deactivateTechnician(technician.id);

      ref.invalidate(dashboardProvider);

      if (!mounted) {
        return;
      }

      _showMessage('${technician.fullName} deactivated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanError(error), isError: true);
    }
  }

  void _showTechnicianDetails(Technician technician) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TechnicianDetailsDialog(
          technician: technician,
          canManage: _canManageTechnicians,
          onEdit: () {
            Navigator.of(dialogContext).pop();
            _editTechnician(technician);
          },
          onDeactivate: () {
            Navigator.of(dialogContext).pop();
            _deactivateTechnician(technician);
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
    final techniciansState = ref.watch(technicianProvider);
    final authState = ref.watch(authProvider);

    final role = _normalizeRole(authState.user?['role']?.toString());

    final canManage = role == 'ADMIN' || role == 'SERVICE_MANAGER';

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;

        return RefreshIndicator(
          onRefresh: () {
            return ref.read(technicianProvider.notifier).refreshTechnicians();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            children: [
              _TechniciansHeader(
                canManage: canManage,
                onAdd: _addTechnician,
                onRefresh: () {
                  ref.read(technicianProvider.notifier).refreshTechnicians();
                },
              ),
              const SizedBox(height: 20),
              techniciansState.when(
                data: (technicians) {
                  return _buildTechnicianContent(
                    technicians,
                    constraints.maxWidth,
                    canManage,
                  );
                },
                loading: () => const _TechniciansLoading(),
                error: (error, stackTrace) {
                  return _TechniciansError(
                    message: _cleanError(error),
                    onRetry: () {
                      ref
                          .read(technicianProvider.notifier)
                          .refreshTechnicians();
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

  Widget _buildTechnicianContent(
    List<Technician> technicians,
    double availableWidth,
    bool canManage,
  ) {
    final statuses =
        technicians
            .map((technician) => technician.status.trim().toUpperCase())
            .where((status) => status.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final filteredTechnicians = technicians.where((technician) {
      final searchableValues = [
        technician.technicianCode,
        technician.fullName,
        technician.mobile,
        technician.specialization ?? '',
        technician.experienceYears.toString(),
        technician.status,
        technician.availabilityStatus,
        technician.userId?.toString() ?? '',
      ].join(' ').toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty || searchableValues.contains(_searchQuery);

      final normalizedStatus = technician.status.trim().toUpperCase();

      final matchesStatus =
          _selectedStatus == 'ALL' || normalizedStatus == _selectedStatus;

      final matchesAccount =
          _selectedAccountFilter == 'ALL' ||
          (_selectedAccountFilter == 'LINKED' && technician.userId != null) ||
          (_selectedAccountFilter == 'UNLINKED' && technician.userId == null);

      return matchesSearch && matchesStatus && matchesAccount;
    }).toList();

    filteredTechnicians.sort(
      (first, second) =>
          first.fullName.toLowerCase().compareTo(second.fullName.toLowerCase()),
    );

    final activeCount = technicians
        .where((technician) => technician.isActive)
        .length;

    final linkedCount = technicians
        .where((technician) => technician.userId != null)
        .length;

    final averageExperience = technicians.isEmpty
        ? 0.0
        : technicians
                  .map((technician) => technician.experienceYears)
                  .fold<int>(0, (total, years) => total + years) /
              technicians.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TechnicianMetrics(
          totalCount: technicians.length,
          activeCount: activeCount,
          linkedCount: linkedCount,
          averageExperience: averageExperience,
        ),
        const SizedBox(height: 18),
        _TechnicianFilters(
          searchController: _searchController,
          statuses: statuses,
          selectedStatus: _selectedStatus,
          selectedAccountFilter: _selectedAccountFilter,
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
          onAccountChanged: (value) {
            setState(() {
              _selectedAccountFilter = value ?? 'ALL';
            });
          },
          onClear: _clearFilters,
        ),
        const SizedBox(height: 16),
        _TechnicianCountBar(
          visibleCount: filteredTechnicians.length,
          totalCount: technicians.length,
        ),
        const SizedBox(height: 14),
        if (filteredTechnicians.isEmpty)
          _EmptyTechnicians(
            hasFilters:
                _searchQuery.isNotEmpty ||
                _selectedStatus != 'ALL' ||
                _selectedAccountFilter != 'ALL',
            canManage: canManage,
            onClearFilters: _clearFilters,
            onAdd: _addTechnician,
          )
        else if (availableWidth >= 1050)
          _TechniciansTable(
            technicians: filteredTechnicians,
            canManage: canManage,
            onView: _showTechnicianDetails,
            onEdit: _editTechnician,
            onDeactivate: _deactivateTechnician,
          )
        else
          _TechniciansCardList(
            technicians: filteredTechnicians,
            canManage: canManage,
            onView: _showTechnicianDetails,
            onEdit: _editTechnician,
            onDeactivate: _deactivateTechnician,
          ),
      ],
    );
  }
}

class _TechniciansHeader extends StatelessWidget {
  const _TechniciansHeader({
    required this.canManage,
    required this.onAdd,
    required this.onRefresh,
  });

  final bool canManage;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;

            final title = Row(
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  tween: Tween(begin: 0.82, end: 1),
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.engineering_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technicians',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage service technicians, skills '
                        'and account connections.',
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
                  tooltip: 'Refresh technicians',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (canManage) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add Technician'),
                  ),
                ],
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerRight, child: actions),
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
        ),
      ),
    );
  }
}

class _TechnicianMetrics extends StatelessWidget {
  const _TechnicianMetrics({
    required this.totalCount,
    required this.activeCount,
    required this.linkedCount,
    required this.averageExperience,
  });

  final int totalCount;
  final int activeCount;
  final int linkedCount;
  final double averageExperience;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _TechnicianMetricData(
        title: 'Total Technicians',
        value: totalCount.toString(),
        icon: Icons.groups_2_outlined,
      ),
      _TechnicianMetricData(
        title: 'Active',
        value: activeCount.toString(),
        icon: Icons.verified_user_outlined,
      ),
      _TechnicianMetricData(
        title: 'Login Connected',
        value: linkedCount.toString(),
        icon: Icons.link_rounded,
      ),
      _TechnicianMetricData(
        title: 'Average Experience',
        value: '${averageExperience.toStringAsFixed(1)} yrs',
        icon: Icons.workspace_premium_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (var index = 0; index < cards.length; index++)
              SizedBox(
                width: width,
                child: TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 280 + (index * 70)),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 14 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _TechnicianMetricCard(data: cards[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TechnicianMetricData {
  const _TechnicianMetricData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _TechnicianMetricCard extends StatelessWidget {
  const _TechnicianMetricCard({required this.data});

  final _TechnicianMetricData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _TechnicianFilters extends StatelessWidget {
  const _TechnicianFilters({
    required this.searchController,
    required this.statuses,
    required this.selectedStatus,
    required this.selectedAccountFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onAccountChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final List<String> statuses;
  final String selectedStatus;
  final String selectedAccountFilter;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onAccountChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        searchController.text.trim().isNotEmpty ||
        selectedStatus != 'ALL' ||
        selectedAccountFilter != 'ALL';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useRow = constraints.maxWidth >= 1100;

            final searchField = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search technicians',
                hintText: 'Name, code, mobile or specialization',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );

            final statusField = DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.toggle_on_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('All statuses'),
                ),
                ...statuses.map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(_formatStatus(status)),
                  ),
                ),
              ],
              onChanged: onStatusChanged,
            );

            final accountField = DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedAccountFilter,
              decoration: const InputDecoration(
                labelText: 'Login account',
                prefixIcon: Icon(Icons.account_circle_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All technicians')),
                DropdownMenuItem(
                  value: 'LINKED',
                  child: Text('Login connected'),
                ),
                DropdownMenuItem(
                  value: 'UNLINKED',
                  child: Text('Not connected'),
                ),
              ],
              onChanged: onAccountChanged,
            );

            final clearButton = OutlinedButton.icon(
              onPressed: hasFilters ? onClear : null,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Clear'),
            );

            if (useRow) {
              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 14),
                  Expanded(child: statusField),
                  const SizedBox(width: 14),
                  Expanded(child: accountField),
                  const SizedBox(width: 14),
                  clearButton,
                ],
              );
            }

            return Column(
              children: [
                searchField,
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: statusField),
                    const SizedBox(width: 12),
                    Expanded(child: accountField),
                  ],
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: clearButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TechnicianCountBar extends StatelessWidget {
  const _TechnicianCountBar({
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
          '$visibleCount technician'
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

class _TechniciansTable extends StatelessWidget {
  const _TechniciansTable({
    required this.technicians,
    required this.canManage,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Technician> technicians;
  final bool canManage;

  final ValueChanged<Technician> onView;
  final ValueChanged<Technician> onEdit;
  final ValueChanged<Technician> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 22,
          columnSpacing: 30,
          columns: const [
            DataColumn(label: Text('Technician')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Specialization')),
            DataColumn(label: Text('Experience')),
            DataColumn(label: Text('Account')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Joined')),
            DataColumn(label: Text('Actions')),
          ],
          rows: technicians.map((technician) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            _initials(technician.fullName),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                technician.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                technician.technicianCode,
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
                  ),
                ),
                DataCell(Text(technician.mobile)),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Text(
                      technician.specialization ?? 'General service',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${technician.experienceYears} '
                    '${technician.experienceYears == 1 ? 'year' : 'years'}',
                  ),
                ),
                DataCell(_AccountBadge(isLinked: technician.userId != null)),
                DataCell(_TechnicianStatusBadge(status: technician.status)),
                DataCell(Text(_formatDate(technician.createdAt))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View technician',
                        onPressed: () {
                          onView(technician);
                        },
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                      if (canManage) ...[
                        IconButton(
                          tooltip: 'Edit technician',
                          onPressed: () {
                            onEdit(technician);
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: technician.isActive
                              ? 'Deactivate technician'
                              : 'Technician inactive',
                          onPressed: technician.isActive
                              ? () {
                                  onDeactivate(technician);
                                }
                              : null,
                          color: AppColors.danger,
                          icon: const Icon(Icons.person_off_outlined),
                        ),
                      ],
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

class _TechniciansCardList extends StatelessWidget {
  const _TechniciansCardList({
    required this.technicians,
    required this.canManage,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Technician> technicians;
  final bool canManage;

  final ValueChanged<Technician> onView;
  final ValueChanged<Technician> onEdit;
  final ValueChanged<Technician> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: technicians.map((technician) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                onView(technician);
              },
              child: Padding(
                padding: const EdgeInsets.all(19),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            _initials(technician.fullName),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                technician.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                technician.technicianCode,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TechnicianStatusBadge(status: technician.status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _TechnicianInfoRow(
                      icon: Icons.phone_outlined,
                      value: technician.mobile,
                    ),
                    const SizedBox(height: 9),
                    _TechnicianInfoRow(
                      icon: Icons.handyman_outlined,
                      value: technician.specialization ?? 'General service',
                    ),
                    const SizedBox(height: 9),
                    _TechnicianInfoRow(
                      icon: Icons.workspace_premium_outlined,
                      value:
                          '${technician.experienceYears} '
                          '${technician.experienceYears == 1 ? 'year' : 'years'} experience',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AccountBadge(isLinked: technician.userId != null),
                        _InformationBadge(
                          icon: Icons.calendar_month_outlined,
                          text: 'Joined ${_formatDate(technician.createdAt)}',
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (canManage) ...[
                          TextButton.icon(
                            onPressed: () {
                              onEdit(technician);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: technician.isActive
                                ? 'Deactivate technician'
                                : 'Technician inactive',
                            onPressed: technician.isActive
                                ? () {
                                    onDeactivate(technician);
                                  }
                                : null,
                            color: AppColors.danger,
                            icon: const Icon(Icons.person_off_outlined),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            onView(technician);
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

class _TechnicianDetailsDialog extends StatelessWidget {
  const _TechnicianDetailsDialog({
    required this.technician,
    required this.canManage,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Technician technician;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      _initials(technician.fullName),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          technician.fullName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          technician.technicianCode,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TechnicianStatusBadge(status: technician.status),
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
              const SizedBox(height: 26),
              _DetailsSection(
                title: 'Contact Information',
                icon: Icons.contact_phone_outlined,
                children: [
                  _DetailsRow(label: 'Full name', value: technician.fullName),
                  _DetailsRow(label: 'Mobile number', value: technician.mobile),
                  _DetailsRow(
                    label: 'Technician code',
                    value: technician.technicianCode,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Professional Information',
                icon: Icons.handyman_outlined,
                children: [
                  _DetailsRow(
                    label: 'Specialization',
                    value: technician.specialization ?? 'General service',
                  ),
                  _DetailsRow(
                    label: 'Experience',
                    value:
                        '${technician.experienceYears} '
                        '${technician.experienceYears == 1 ? 'year' : 'years'}',
                  ),
                  _DetailsRow(
                    label: 'Availability',
                    value: _formatStatus(technician.availabilityStatus),
                  ),
                  _DetailsRow(
                    label: 'Profile status',
                    value: _formatStatus(technician.status),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'System Information',
                icon: Icons.admin_panel_settings_outlined,
                children: [
                  _DetailsRow(
                    label: 'Login account',
                    value: technician.userId == null
                        ? 'Not connected'
                        : 'Connected to user ID '
                              '${technician.userId}',
                  ),
                  _DetailsRow(
                    label: 'Created on',
                    value: _formatDate(technician.createdAt),
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
                  if (canManage) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: technician.isActive ? onDeactivate : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Deactivate'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Technician'),
                    ),
                  ],
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
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 15),
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
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
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

class _TechnicianStatusBadge extends StatelessWidget {
  const _TechnicianStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().toUpperCase();

    final isActive = normalizedStatus == 'ACTIVE';

    final color = isActive ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.isLinked});

  final bool isLinked;

  @override
  Widget build(BuildContext context) {
    final color = isLinked ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLinked ? Icons.link_rounded : Icons.link_off_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isLinked ? 'Login connected' : 'No login',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationBadge extends StatelessWidget {
  const _InformationBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianInfoRow extends StatelessWidget {
  const _TechnicianInfoRow({required this.icon, required this.value});

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

class _EmptyTechnicians extends StatelessWidget {
  const _EmptyTechnicians({
    required this.hasFilters,
    required this.canManage,
    required this.onClearFilters,
    required this.onAdd,
  });

  final bool hasFilters;
  final bool canManage;
  final VoidCallback onClearFilters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.engineering_outlined,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                hasFilters ? 'No matching technicians' : 'No technicians added',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasFilters
                    ? 'Change or clear the filters to view '
                          'more technicians.'
                    : 'Technician profiles will appear here '
                          'after they are added.',
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
              else if (canManage)
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add Technician'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechniciansLoading extends StatelessWidget {
  const _TechniciansLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(child: LinearProgressIndicator(minHeight: 7)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TechniciansError extends StatelessWidget {
  const _TechniciansError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load technicians',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _normalizeRole(String? role) {
  return role?.trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', '_') ??
      '';
}

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'T';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}'
          '${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatStatus(String value) {
  final normalized = value
      .trim()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .toLowerCase();

  if (normalized.isEmpty) {
    return 'Unknown';
  }

  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _formatDate(DateTime value) {
  final localValue = value.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${localValue.day.toString().padLeft(2, '0')} '
      '${months[localValue.month - 1]} '
      '${localValue.year}';
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('ApiException: ', '')
      .trim();
}
