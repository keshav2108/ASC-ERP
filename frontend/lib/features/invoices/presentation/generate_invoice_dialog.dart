import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../job_cards/data/job_card_model.dart';
import '../data/invoice_model.dart';

class GenerateInvoiceDialog extends StatefulWidget {
  const GenerateInvoiceDialog({
    required this.jobCards,
    required this.existingInvoices,
    required this.onGenerate,
    super.key,
  });

  final List<JobCard> jobCards;
  final List<Invoice> existingInvoices;

  final Future<void> Function(InvoiceCreateInput input) onGenerate;

  @override
  State<GenerateInvoiceDialog> createState() => _GenerateInvoiceDialogState();
}

class _GenerateInvoiceDialogState extends State<GenerateInvoiceDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _discountController = TextEditingController(text: '0.00');

  final _gstController = TextEditingController(text: '0.00');

  late final AnimationController _animationController;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  int? _selectedJobCardId;

  bool _isSaving = false;
  String? _errorMessage;

  List<JobCard> get _eligibleJobCards {
    final invoicedJobCardIds = widget.existingInvoices
        .map((invoice) => invoice.jobCardId)
        .toSet();

    final eligible = widget.jobCards.where((jobCard) {
      final status = _normalizeStatus(jobCard.status);

      final isEligibleStatus =
          status == 'COMPLETED' || status == 'READY_FOR_DELIVERY';

      final isAlreadyInvoiced = invoicedJobCardIds.contains(jobCard.id);

      return isEligibleStatus && !isAlreadyInvoiced;
    }).toList();

    eligible.sort((first, second) => second.id.compareTo(first.id));

    return eligible;
  }

  JobCard? get _selectedJobCard {
    final selectedId = _selectedJobCardId;

    if (selectedId == null) {
      return null;
    }

    for (final jobCard in _eligibleJobCards) {
      if (jobCard.id == selectedId) {
        return jobCard;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    final eligible = _eligibleJobCards;

    if (eligible.isNotEmpty) {
      _selectedJobCardId = eligible.first.id;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _gstController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final jobCardId = _selectedJobCardId;

    if (jobCardId == null) {
      setState(() {
        _errorMessage = 'Select an eligible Job Card.';
      });

      return;
    }

    final discountAmount =
        double.tryParse(_discountController.text.trim()) ?? 0;

    final gstPercentage = double.tryParse(_gstController.text.trim()) ?? 0;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onGenerate(
        InvoiceCreateInput(
          jobCardId: jobCardId,
          discountAmount: discountAmount,
          gstPercentage: gstPercentage,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
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
          _isSaving = false;
        });
      }
    }
  }

  void _applyGst(double value) {
    setState(() {
      _gstController.text = value.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eligibleJobCards = _eligibleJobCards;

    final screenSize = MediaQuery.sizeOf(context);

    final dialogWidth = screenSize.width < 760 ? screenSize.width - 32 : 700.0;

    final dialogHeight = screenSize.height < 760
        ? screenSize.height - 32
        : 720.0;

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: eligibleJobCards.isEmpty
                        ? _buildEmptyState(context)
                        : _buildForm(context, eligibleJobCards),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 20),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Invoice',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create the final bill from labour and issued spare parts.',
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Job Card is ready',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Complete the repair workflow first. '
                'Only Completed or Ready for Delivery '
                'Job Cards without an existing invoice '
                'can be selected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Return to Invoices'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<JobCard> eligibleJobCards) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    context,
                    icon: Icons.assignment_outlined,
                    title: 'Select Job Card',
                    subtitle: 'Only completed repair jobs are available.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedJobCardId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Eligible Job Card',
                      prefixIcon: Icon(Icons.engineering_outlined),
                    ),
                    items: eligibleJobCards
                        .map(
                          (jobCard) => DropdownMenuItem<int>(
                            value: jobCard.id,
                            child: Text(
                              '${jobCard.jobCode} • '
                              '${jobCard.serviceRequest.requestCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedJobCardId = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Select a Job Card.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _selectedJobCard == null
                        ? const SizedBox.shrink()
                        : _buildJobCardSummary(context, _selectedJobCard!),
                  ),
                  const SizedBox(height: 28),
                  _buildSectionTitle(
                    context,
                    icon: Icons.calculate_outlined,
                    title: 'Billing Adjustments',
                    subtitle:
                        'Labour and spare-part totals are calculated automatically.',
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final discountField = _buildMoneyField(
                        controller: _discountController,
                        label: 'Discount amount',
                        icon: Icons.discount_outlined,
                        validator: _validateDiscount,
                      );

                      final gstField = _buildMoneyField(
                        controller: _gstController,
                        label: 'GST percentage',
                        icon: Icons.percent_rounded,
                        validator: _validateGst,
                        suffixText: '%',
                      );

                      if (constraints.maxWidth < 520) {
                        return Column(
                          children: [
                            discountField,
                            const SizedBox(height: 16),
                            gstField,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: discountField),
                          const SizedBox(width: 16),
                          Expanded(child: gstField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildGstPresets(),
                  const SizedBox(height: 24),
                  _buildCalculationNote(context),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _buildErrorBox(_errorMessage!),
                  ],
                ],
              ),
            ),
          ),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJobCardSummary(BuildContext context, JobCard jobCard) {
    return Container(
      key: ValueKey(jobCard.id),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Job Card', value: jobCard.jobCode),
          _SummaryRow(
            label: 'Service Request',
            value: jobCard.serviceRequest.requestCode,
          ),
          _SummaryRow(label: 'Technician', value: jobCard.technician.fullName),
          _SummaryRow(
            label: 'Status',
            value: _formatStatus(jobCard.status),
            valueColor: AppColors.success,
          ),
          _SummaryRow(
            label: 'Labour charge',
            value: '₹${jobCard.labourCharge.toStringAsFixed(2)}',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    String? suffixText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: suffixText == null ? '₹ ' : null,
        suffixText: suffixText,
      ),
      validator: validator,
    );
  }

  Widget _buildGstPresets() {
    const gstValues = <double>[0, 5, 12, 18, 28];

    final selectedGst = double.tryParse(_gstController.text.trim()) ?? 0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: gstValues.map((value) {
        final isSelected = selectedGst == value;

        return ChoiceChip(
          label: Text('${value.toStringAsFixed(0)}% GST'),
          selected: isSelected,
          onSelected: _isSaving
              ? null
              : (_) {
                  _applyGst(value);
                },
        );
      }).toList(),
    );
  }

  Widget _buildCalculationNote(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'The server will calculate labour amount, '
              'net issued spare-part amount, subtotal, '
              'discount, taxable value, GST and final total.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 11),
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

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
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
            onPressed: _isSaving ? null : _submit,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.receipt_long_rounded),
            label: Text(_isSaving ? 'Generating...' : 'Generate Invoice'),
          ),
        ],
      ),
    );
  }

  String? _validateDiscount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');

    if (amount == null) {
      return 'Enter a valid amount.';
    }

    if (amount < 0) {
      return 'Discount cannot be negative.';
    }

    return null;
  }

  String? _validateGst(String? value) {
    final gst = double.tryParse(value?.trim() ?? '');

    if (gst == null) {
      return 'Enter a valid percentage.';
    }

    if (gst < 0 || gst > 100) {
      return 'GST must be between 0 and 100.';
    }

    return null;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
              textAlign: TextAlign.right,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
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

String _cleanError(Object error) {
  final message = error.toString().trim();

  if (message.startsWith('Exception: ')) {
    return message.substring(11);
  }

  return message;
}
