import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../data/job_card_model.dart';
import '../data/job_card_provider.dart';

class JobCardWorkflowDialog extends ConsumerStatefulWidget {
  const JobCardWorkflowDialog({required this.jobCard, super.key});

  final JobCard jobCard;

  @override
  ConsumerState<JobCardWorkflowDialog> createState() =>
      _JobCardWorkflowDialogState();
}

class _JobCardWorkflowDialogState extends ConsumerState<JobCardWorkflowDialog> {
  late JobCard _jobCard;

  bool _isUpdating = false;
  String? _errorMessage;

  static const Set<String> _technicianAllowedTargets = <String>{
    'ACCEPTED',
    'DIAGNOSIS',
    'WAITING_PARTS',
    'REPAIR_IN_PROGRESS',
    'TESTING',
    'COMPLETED',
  };

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

  bool get _canManageWorkflow {
    return _currentUserRole == 'ADMIN' || _currentUserRole == 'SERVICE_MANAGER';
  }

  bool get _isTechnician {
    return _currentUserRole == 'TECHNICIAN';
  }

  bool _canRunTransitionTo(String targetStatus) {
    if (_canManageWorkflow) {
      return true;
    }

    if (_isTechnician) {
      return _technicianAllowedTargets.contains(targetStatus);
    }

    return false;
  }

  void _showPermissionError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
  }

  @override
  void initState() {
    super.initState();
    _jobCard = widget.jobCard;
  }

  Future<void> _runTransition(WorkflowTransition transition) async {
    if (_isUpdating) {
      return;
    }

    final targetStatus = _normalizeStatus(transition.toStatus);

    if (!_canRunTransitionTo(targetStatus)) {
      _showPermissionError(
        'You do not have permission to move this job card '
        'to ${_formatStatus(targetStatus)}.',
      );

      return;
    }

    if (targetStatus == 'DELIVERED') {
      await _openDeliveryDialog();
      return;
    }

    final isCancellation = targetStatus == 'CANCELLED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isCancellation ? 'Cancel job card?' : _transitionLabel(transition),
          ),
          content: Text(
            isCancellation
                ? '${_jobCard.jobCode} will be '
                      'cancelled. This action cannot '
                      'be reversed through the workflow.'
                : 'Move ${_jobCard.jobCode} from '
                      '${_formatStatus(_jobCard.status)} '
                      'to ${_formatStatus(targetStatus)}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Go Back'),
            ),
            FilledButton(
              style: isCancellation
                  ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                  : null,
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(isCancellation ? 'Cancel Job' : 'Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final updatedJobCard = await ref
          .read(jobCardProvider.notifier)
          .changeStatus(_jobCard.id, targetStatus);

      if (!mounted) {
        return;
      }

      setState(() {
        _jobCard = updatedJobCard;
      });

      _showMessage(
        '${updatedJobCard.jobCode} moved to '
        '${_formatStatus(updatedJobCard.status)}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _openDeliveryDialog() async {
    if (!_canManageWorkflow) {
      _showPermissionError(
        'Only Admin or Service Manager can deliver a product.',
      );

      return;
    }

    final deliveredJobCard = await showDialog<JobCard>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _JobCardDeliveryDialog(jobCard: _jobCard);
      },
    );

    if (deliveredJobCard == null || !mounted) {
      return;
    }

    setState(() {
      _jobCard = deliveredJobCard;
      _errorMessage = null;
    });

    _showMessage('${deliveredJobCard.jobCode} delivered successfully.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
      );
  }

  @override
  Widget build(BuildContext context) {
    final transitionsState = ref.watch(
      allowedJobTransitionsProvider(_jobCard.status),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildJobSummary(),
              const SizedBox(height: 22),
              _buildCurrentStage(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                _WorkflowErrorBox(message: _errorMessage!),
              ],
              const SizedBox(height: 24),
              Text(
                'Available Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _buildTransitionContent(transitionsState),
              const SizedBox(height: 26),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () {
                          Navigator.of(context).pop(_jobCard);
                        },
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
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
                'Job Card Workflow',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Move the repair through its approved stages.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _isUpdating
              ? null
              : () {
                  Navigator.of(context).pop(_jobCard);
                },
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildJobSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _jobCard.jobCode,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _WorkflowInformationRow(
            label: 'Request',
            value: _jobCard.serviceRequest.requestCode,
          ),
          _WorkflowInformationRow(
            label: 'Technician',
            value:
                '${_jobCard.technician.fullName} '
                '(${_jobCard.technician.technicianCode})',
          ),
          _WorkflowInformationRow(
            label: 'Complaint',
            value: _formatStatus(_jobCard.serviceRequest.complaintCategory),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStage() {
    final statusColor = _statusColor(_jobCard.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon(_jobCard.status), color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Stage',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatStatus(_jobCard.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (_isUpdating)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildTransitionContent(
    AsyncValue<List<WorkflowTransition>> transitionsState,
  ) {
    if (_jobCard.isClosed) {
      return const _NoWorkflowActions(
        icon: Icons.lock_outline_rounded,
        message: 'This job card is closed and has no further actions.',
      );
    }

    return transitionsState.when(
      data: (transitions) {
        final visibleTransitions = transitions
            .where((transition) {
              final targetStatus = _normalizeStatus(transition.toStatus);

              return _canRunTransitionTo(targetStatus);
            })
            .toList(growable: false);

        if (visibleTransitions.isEmpty) {
          final hasWorkflowRole = _canManageWorkflow || _isTechnician;

          return _NoWorkflowActions(
            icon: hasWorkflowRole
                ? Icons.info_outline_rounded
                : Icons.lock_outline_rounded,
            message: hasWorkflowRole
                ? 'No permitted workflow action is available '
                      'for the current stage.'
                : 'Your role does not have permission to '
                      'manage job card workflow.',
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visibleTransitions.map((transition) {
            final targetStatus = _normalizeStatus(transition.toStatus);

            final isCancellation = targetStatus == 'CANCELLED';

            final isDelivery = targetStatus == 'DELIVERED';

            return FilledButton.icon(
              style: isCancellation
                  ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                  : isDelivery
                  ? FilledButton.styleFrom(backgroundColor: AppColors.success)
                  : null,
              onPressed: _isUpdating
                  ? null
                  : () {
                      _runTransition(transition);
                    },
              icon: Icon(_transitionIcon(targetStatus)),
              label: Text(_transitionLabel(transition)),
            );
          }).toList(),
        );
      },
      loading: () => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                _cleanError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(
                    allowedJobTransitionsProvider(_jobCard.status),
                  );
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JobCardDeliveryDialog extends ConsumerStatefulWidget {
  const _JobCardDeliveryDialog({required this.jobCard});

  final JobCard jobCard;

  @override
  ConsumerState<_JobCardDeliveryDialog> createState() =>
      _JobCardDeliveryDialogState();
}

class _JobCardDeliveryDialogState
    extends ConsumerState<_JobCardDeliveryDialog> {
  final _formKey = GlobalKey<FormState>();

  final _deliveredToController = TextEditingController();

  final _remarksController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _deliveredToController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _deliver() async {
    FocusScope.of(context).unfocus();

    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final deliveredJobCard = await ref
          .read(jobCardProvider.notifier)
          .deliverJobCard(
            widget.jobCard.id,
            JobCardDeliveryInput(
              deliveredTo: _deliveredToController.text,
              deliveryRemarks: _remarksController.text,
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(deliveredJobCard);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanError(error);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: AppColors.success),
          SizedBox(width: 10),
          Text('Deliver Product'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.jobCard.jobCode} • '
                  '${widget.jobCard.serviceRequest.requestCode}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _deliveredToController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Delivered to',
                    hintText: 'Customer or receiver name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final receiver = value?.trim() ?? '';

                    if (receiver.isEmpty) {
                      return 'Enter receiver name.';
                    }

                    if (receiver.length < 2) {
                      return 'Enter at least 2 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Delivery remarks',
                    hintText: 'Optional delivery notes',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _WorkflowErrorBox(message: _errorMessage!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: _isSaving ? null : _deliver,
          icon: _isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_isSaving ? 'Delivering...' : 'Confirm Delivery'),
        ),
      ],
    );
  }
}

class _WorkflowInformationRow extends StatelessWidget {
  const _WorkflowInformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
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

class _NoWorkflowActions extends StatelessWidget {
  const _NoWorkflowActions({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WorkflowErrorBox extends StatelessWidget {
  const _WorkflowErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
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

String _transitionLabel(WorkflowTransition transition) {
  final action = transition.action.trim();

  if (action.isNotEmpty) {
    return action;
  }

  return 'Move to '
      '${_formatStatus(transition.toStatus)}';
}

String _normalizeStatus(String status) {
  return status.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
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

IconData _transitionIcon(String status) {
  return switch (_normalizeStatus(status)) {
    'ACCEPTED' => Icons.thumb_up_alt_outlined,
    'DIAGNOSIS' => Icons.search_rounded,
    'WAITING_PARTS' => Icons.inventory_2_outlined,
    'REPAIR_IN_PROGRESS' => Icons.build_outlined,
    'TESTING' => Icons.science_outlined,
    'COMPLETED' => Icons.task_alt_rounded,
    'READY_FOR_DELIVERY' => Icons.inventory_outlined,
    'DELIVERED' => Icons.local_shipping_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    _ => Icons.arrow_forward_rounded,
  };
}

IconData _statusIcon(String status) {
  return switch (_normalizeStatus(status)) {
    'ASSIGNED' => Icons.assignment_ind_outlined,
    'ACCEPTED' => Icons.thumb_up_alt_outlined,
    'DIAGNOSIS' => Icons.search_rounded,
    'WAITING_PARTS' => Icons.inventory_2_outlined,
    'REPAIR_IN_PROGRESS' => Icons.build_outlined,
    'TESTING' => Icons.science_outlined,
    'COMPLETED' => Icons.task_alt_rounded,
    'READY_FOR_DELIVERY' => Icons.inventory_outlined,
    'DELIVERED' => Icons.local_shipping_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    _ => Icons.info_outline_rounded,
  };
}

Color _statusColor(String status) {
  return switch (_normalizeStatus(status)) {
    'DELIVERED' || 'COMPLETED' || 'READY_FOR_DELIVERY' => AppColors.success,
    'CANCELLED' => AppColors.danger,
    'WAITING_PARTS' => Colors.orange,
    'DIAGNOSIS' || 'REPAIR_IN_PROGRESS' || 'TESTING' => Colors.blue,
    _ => AppColors.primary,
  };
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
