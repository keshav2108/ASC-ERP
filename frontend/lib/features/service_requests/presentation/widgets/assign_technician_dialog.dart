import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../job_cards/data/job_card_model.dart';
import '../../../job_cards/data/job_card_provider.dart';
import '../../../technicians/data/technician_model.dart';
import '../../../technicians/data/technician_provider.dart';
import '../../data/service_request_model.dart';

class AssignTechnicianDialog extends ConsumerStatefulWidget {
  const AssignTechnicianDialog({required this.serviceRequest, super.key});

  final ServiceRequest serviceRequest;

  @override
  ConsumerState<AssignTechnicianDialog> createState() =>
      _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState
    extends ConsumerState<AssignTechnicianDialog> {
  final _formKey = GlobalKey<FormState>();

  final _diagnosisController = TextEditingController();

  final _repairNotesController = TextEditingController();

  final _labourChargeController = TextEditingController(text: '0');

  int? _selectedTechnicianId;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _repairNotesController.dispose();
    _labourChargeController.dispose();

    super.dispose();
  }

  Future<void> _assignTechnician() async {
    if (_isSubmitting) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final technicianId = _selectedTechnicianId;

    if (technicianId == null) {
      setState(() {
        _errorMessage = 'Please select a technician.';
      });

      return;
    }

    final labourCharge =
        double.tryParse(_labourChargeController.text.trim()) ?? 0;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final jobCard = await ref
          .read(jobCardProvider.notifier)
          .assignTechnician(
            widget.serviceRequest.id,
            TechnicianAssignmentInput(
              technicianId: technicianId,
              diagnosis: _diagnosisController.text,
              repairNotes: _repairNotesController.text,
              labourCharge: labourCharge,
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(jobCard);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableTechnicians = ref.watch(availableTechniciansProvider);

    final theme = Theme.of(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: _DialogHeader(serviceRequest: widget.serviceRequest),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: availableTechnicians.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) {
              return _TechnicianLoadError(
                message: error.toString(),
                onRetry: () {
                  ref.invalidate(technicianProvider);
                },
              );
            },
            data: (technicians) {
              if (technicians.isEmpty) {
                return const _NoTechniciansAvailable();
              }

              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _selectedTechnicianId,
                      decoration: const InputDecoration(
                        labelText: 'Select technician',
                        prefixIcon: Icon(Icons.engineering_rounded),
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: technicians.map((technician) {
                        return DropdownMenuItem<int>(
                          value: technician.id,
                          child: _TechnicianOption(technician: technician),
                        );
                      }).toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (technicianId) {
                              setState(() {
                                _selectedTechnicianId = technicianId;

                                _errorMessage = null;
                              });
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Select a technician';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _diagnosisController,
                      enabled: !_isSubmitting,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Initial diagnosis',
                        hintText: 'Optional initial inspection details',
                        prefixIcon: Icon(Icons.search_rounded),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _repairNotesController,
                      enabled: !_isSubmitting,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 3000,
                      decoration: const InputDecoration(
                        labelText: 'Repair notes',
                        hintText: 'Optional repair instructions',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _labourChargeController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Initial labour charge',
                        prefixText: '₹ ',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Enter labour charge';
                        }

                        final charge = double.tryParse(text);

                        if (charge == null) {
                          return 'Enter a valid amount';
                        }

                        if (charge < 0) {
                          return 'Amount cannot be negative';
                        }

                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: availableTechnicians.value?.isNotEmpty == true
              ? (_isSubmitting ? null : _assignTechnician)
              : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.assignment_ind_rounded),
          label: Text(_isSubmitting ? 'Assigning...' : 'Assign Technician'),
        ),
      ],
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.serviceRequest});

  final ServiceRequest serviceRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.assignment_ind_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign Technician',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${serviceRequest.requestCode} • '
                  '${serviceRequest.customer.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  serviceRequest.customerProduct.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
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
}

class _TechnicianOption extends StatelessWidget {
  const _TechnicianOption({required this.technician});

  final Technician technician;

  @override
  Widget build(BuildContext context) {
    final specialization = technician.specialization;

    return Row(
      children: [
        const Icon(Icons.person_outline_rounded, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            specialization == null || specialization.isEmpty
                ? technician.displayName
                : '${technician.displayName} — '
                      '$specialization',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _NoTechniciansAvailable extends StatelessWidget {
  const _NoTechniciansAvailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.engineering_outlined,
            size: 54,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 14),
          Text(
            'No technicians available',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All active technicians are currently busy. '
            'Complete or cancel an existing job, or add '
            'another technician.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TechnicianLoadError extends StatelessWidget {
  const _TechnicianLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load technicians',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
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
