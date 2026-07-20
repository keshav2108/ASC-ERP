import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../technicians/data/technician_model.dart';
import '../../technicians/data/technician_provider.dart';
import '../data/job_card_model.dart';
import '../data/job_card_provider.dart';

class JobCardEditDialog extends ConsumerStatefulWidget {
  const JobCardEditDialog({required this.jobCard, super.key});

  final JobCard jobCard;

  @override
  ConsumerState<JobCardEditDialog> createState() => _JobCardEditDialogState();
}

class _JobCardEditDialogState extends ConsumerState<JobCardEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _diagnosisController;

  late final TextEditingController _repairNotesController;

  late final TextEditingController _labourChargeController;

  late int _selectedTechnicianId;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _selectedTechnicianId = widget.jobCard.technicianId;

    _diagnosisController = TextEditingController(
      text: widget.jobCard.diagnosis ?? '',
    );

    _repairNotesController = TextEditingController(
      text: widget.jobCard.repairNotes ?? '',
    );

    _labourChargeController = TextEditingController(
      text: widget.jobCard.labourCharge.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _repairNotesController.dispose();
    _labourChargeController.dispose();

    super.dispose();
  }

  Future<void> _saveJobCard() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final labourCharge = double.tryParse(_labourChargeController.text.trim());

    if (labourCharge == null) {
      setState(() {
        _errorMessage = 'Enter a valid labour charge.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedJobCard = await ref
          .read(jobCardProvider.notifier)
          .editJobCard(
            widget.jobCard.id,
            JobCardUpdateInput(
              technicianId: _selectedTechnicianId,
              diagnosis: _diagnosisController.text,
              repairNotes: _repairNotesController.text,
              labourCharge: labourCharge,
              includeDiagnosis: true,
              includeRepairNotes: true,
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedJobCard);
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
    final techniciansState = ref.watch(technicianProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildJobIdentity(),
                const SizedBox(height: 22),
                _buildTechnicianField(techniciansState),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _diagnosisController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Diagnosis',
                    hintText: 'Enter inspection and diagnosis details',
                    prefixIcon: Icon(Icons.search_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _repairNotesController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 3000,
                  decoration: const InputDecoration(
                    labelText: 'Repair notes',
                    hintText: 'Enter repair work and observations',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _labourChargeController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Labour charge',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Enter labour charge.';
                    }

                    final amount = double.tryParse(text);

                    if (amount == null) {
                      return 'Enter a valid amount.';
                    }

                    if (amount < 0) {
                      return 'Amount cannot be negative.';
                    }

                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  _ErrorBox(message: _errorMessage!),
                ],
                const SizedBox(height: 26),
                _buildActions(),
              ],
            ),
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
            Icons.edit_note_rounded,
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
                'Edit Job Card',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update technician and repair information.',
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

  Widget _buildJobIdentity() {
    final jobCard = widget.jobCard;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            jobCard.jobCode,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Service Request: '
            '${jobCard.serviceRequest.requestCode}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            _formatStatus(jobCard.serviceRequest.complaintCategory),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianField(AsyncValue<List<Technician>> techniciansState) {
    return techniciansState.when(
      data: (technicians) {
        final selectableTechnicians =
            technicians.where((technician) {
              return technician.isAvailable ||
                  technician.id == widget.jobCard.technicianId;
            }).toList()..sort(
              (first, second) => first.fullName.toLowerCase().compareTo(
                second.fullName.toLowerCase(),
              ),
            );

        final selectedExists = selectableTechnicians.any(
          (technician) => technician.id == _selectedTechnicianId,
        );

        return DropdownButtonFormField<int>(
          key: ValueKey(
            'job-technician-'
            '$_selectedTechnicianId-'
            '${selectableTechnicians.length}',
          ),
          initialValue: selectedExists ? _selectedTechnicianId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Technician',
            prefixIcon: Icon(Icons.engineering_rounded),
          ),
          items: selectableTechnicians
              .map(
                (technician) => DropdownMenuItem<int>(
                  value: technician.id,
                  child: Text(
                    '${technician.fullName} — '
                    '${technician.technicianCode}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _isSaving
              ? null
              : (technicianId) {
                  if (technicianId == null) {
                    return;
                  }

                  setState(() {
                    _selectedTechnicianId = technicianId;

                    _errorMessage = null;
                  });
                },
          validator: (value) {
            if (value == null) {
              return 'Select a technician.';
            }

            return null;
          },
        );
      },
      loading: () => TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Loading technicians...',
          prefixIcon: Icon(Icons.engineering_rounded),
          suffixIcon: Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) {
        return TextFormField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Unable to load technicians',
            prefixIcon: const Icon(
              Icons.engineering_rounded,
              color: AppColors.danger,
            ),
            suffixIcon: IconButton(
              tooltip: 'Retry',
              onPressed: () {
                ref.invalidate(technicianProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
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
          onPressed: _isSaving ? null : _saveJobCard,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

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
