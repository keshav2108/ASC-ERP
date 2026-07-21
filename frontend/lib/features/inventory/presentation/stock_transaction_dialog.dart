import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../job_cards/data/job_card_model.dart';
import '../data/inventory_model.dart';

typedef StockInCallback = Future<void> Function(StockInInput input);

typedef StockIssueCallback = Future<void> Function(StockIssueInput input);

typedef StockReturnCallback = Future<void> Function(StockReturnInput input);

typedef StockAdjustmentCallback =
    Future<void> Function(StockAdjustmentInput input);

enum StockTransactionMode { stockIn, issue, stockReturn, adjustment }

class StockTransactionDialog extends StatefulWidget {
  const StockTransactionDialog._({
    required this.mode,
    required this.sparePart,
    required this.jobCards,
    this.onStockIn,
    this.onIssue,
    this.onReturn,
    this.onAdjustment,
  });

  factory StockTransactionDialog.stockIn({
    required SparePart sparePart,
    required StockInCallback onSubmit,
  }) {
    return StockTransactionDialog._(
      mode: StockTransactionMode.stockIn,
      sparePart: sparePart,
      jobCards: const <JobCard>[],
      onStockIn: onSubmit,
    );
  }

  factory StockTransactionDialog.issue({
    required SparePart sparePart,
    required List<JobCard> jobCards,
    required StockIssueCallback onSubmit,
  }) {
    return StockTransactionDialog._(
      mode: StockTransactionMode.issue,
      sparePart: sparePart,
      jobCards: jobCards,
      onIssue: onSubmit,
    );
  }

  factory StockTransactionDialog.stockReturn({
    required SparePart sparePart,
    required List<JobCard> jobCards,
    required StockReturnCallback onSubmit,
  }) {
    return StockTransactionDialog._(
      mode: StockTransactionMode.stockReturn,
      sparePart: sparePart,
      jobCards: jobCards,
      onReturn: onSubmit,
    );
  }

  factory StockTransactionDialog.adjustment({
    required SparePart sparePart,
    required StockAdjustmentCallback onSubmit,
  }) {
    return StockTransactionDialog._(
      mode: StockTransactionMode.adjustment,
      sparePart: sparePart,
      jobCards: const <JobCard>[],
      onAdjustment: onSubmit,
    );
  }

  final StockTransactionMode mode;
  final SparePart sparePart;
  final List<JobCard> jobCards;

  final StockInCallback? onStockIn;
  final StockIssueCallback? onIssue;
  final StockReturnCallback? onReturn;
  final StockAdjustmentCallback? onAdjustment;

  @override
  State<StockTransactionDialog> createState() => _StockTransactionDialogState();
}

class _StockTransactionDialogState extends State<StockTransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _quantityController;
  late final TextEditingController _referenceController;
  late final TextEditingController _remarksController;

  int? _selectedJobCardId;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _requiresJobCard {
    return widget.mode == StockTransactionMode.issue ||
        widget.mode == StockTransactionMode.stockReturn;
  }

  bool get _isAdjustment {
    return widget.mode == StockTransactionMode.adjustment;
  }

  bool get _isIssue {
    return widget.mode == StockTransactionMode.issue;
  }

  bool get _isStockIn {
    return widget.mode == StockTransactionMode.stockIn;
  }

  List<JobCard> get _availableJobCards {
    final jobCards = widget.jobCards.where((jobCard) {
      if (!_isIssue) {
        return true;
      }

      final status = jobCard.status
          .trim()
          .toUpperCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');

      return !{
        'COMPLETED',
        'READY_FOR_DELIVERY',
        'CANCELLED',
        'DELIVERED',
      }.contains(status);
    }).toList();

    jobCards.sort((first, second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return jobCards;
  }

  int? get _enteredQuantity {
    return int.tryParse(_quantityController.text.trim());
  }

  int get _adjustmentDifference {
    if (!_isAdjustment) {
      return 0;
    }

    final newQuantity = _enteredQuantity;

    if (newQuantity == null) {
      return 0;
    }

    return newQuantity - widget.sparePart.currentStock;
  }

  @override
  void initState() {
    super.initState();

    _quantityController = TextEditingController(
      text: _isAdjustment ? widget.sparePart.currentStock.toString() : '',
    );

    _referenceController = TextEditingController();

    _remarksController = TextEditingController();

    _quantityController.addListener(_handleQuantityChanged);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_handleQuantityChanged);

    _quantityController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();

    super.dispose();
  }

  void _handleQuantityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final quantity = int.parse(_quantityController.text.trim());

      switch (widget.mode) {
        case StockTransactionMode.stockIn:
          await widget.onStockIn!(
            StockInInput(
              sparePartId: widget.sparePart.id,
              quantity: quantity,
              reference: _referenceController.text.trim(),
              remarks: _remarksController.text.trim(),
            ),
          );

        case StockTransactionMode.issue:
          await widget.onIssue!(
            StockIssueInput(
              sparePartId: widget.sparePart.id,
              jobCardId: _selectedJobCardId!,
              quantity: quantity,
              remarks: _remarksController.text.trim(),
            ),
          );

        case StockTransactionMode.stockReturn:
          await widget.onReturn!(
            StockReturnInput(
              sparePartId: widget.sparePart.id,
              jobCardId: _selectedJobCardId!,
              quantity: quantity,
              remarks: _remarksController.text.trim(),
            ),
          );

        case StockTransactionMode.adjustment:
          await widget.onAdjustment!(
            StockAdjustmentInput(
              sparePartId: widget.sparePart.id,
              newQuantity: quantity,
              remarks: _remarksController.text.trim(),
            ),
          );
      }

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

  void _close() {
    if (_isSaving) {
      return;
    }

    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    final dialogWidth = screenSize.width < 650 ? screenSize.width - 32 : 610.0;

    final dialogHeight = screenSize.height < 700
        ? screenSize.height - 32
        : 650.0;

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              _TransactionHeader(
                title: _dialogTitle(widget.mode),
                subtitle: _dialogSubtitle(widget.mode),
                icon: _dialogIcon(widget.mode),
                isSaving: _isSaving,
                onClose: _close,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PartSummaryCard(sparePart: widget.sparePart),
                        const SizedBox(height: 24),
                        Text(
                          'Transaction details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        if (_requiresJobCard) ...[
                          FormField<int>(
                            initialValue: _selectedJobCardId,
                            validator: (value) {
                              if (value == null) {
                                return 'Select a job card.';
                              }

                              return null;
                            },
                            builder: (field) {
                              final availableJobCards = _availableJobCards;

                              return DropdownMenu<int>(
                                initialSelection: _selectedJobCardId,
                                expandedInsets: EdgeInsets.zero,
                                enableFilter: true,
                                enableSearch: true,
                                requestFocusOnTap: true,
                                enabled:
                                    !_isSaving && availableJobCards.isNotEmpty,
                                label: const Text('Job card *'),
                                hintText: 'Search by Job Card code',
                                helperText: availableJobCards.isEmpty
                                    ? 'No eligible active Job Cards are available'
                                    : 'Type a Job Card code, request code, technician, or status',
                                errorText: field.errorText,
                                leadingIcon: const Icon(
                                  Icons.assignment_outlined,
                                ),
                                dropdownMenuEntries: availableJobCards
                                    .map((jobCard) {
                                      final technicianName = jobCard
                                          .technician
                                          .fullName
                                          .trim();

                                      final label =
                                          '${jobCard.jobCode} • '
                                          '${jobCard.serviceRequest.requestCode} • '
                                          '${_formatStatus(jobCard.status)}'
                                          '${technicianName.isEmpty ? '' : ' • $technicianName'}';

                                      return DropdownMenuEntry<int>(
                                        value: jobCard.id,
                                        label: label,
                                      );
                                    })
                                    .toList(growable: false),
                                onSelected: (value) {
                                  setState(() {
                                    _selectedJobCardId = value;
                                  });

                                  field.didChange(value);
                                },
                              );
                            },
                          ),
                          if (_availableJobCards.isEmpty) ...[
                            const SizedBox(height: 12),
                            const _WarningBox(
                              message:
                                  'No active Job Card can receive spare parts. '
                                  'Create a Service Request and assign a technician first.',
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _quantityController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: _isAdjustment
                                ? 'New stock quantity *'
                                : 'Quantity *',
                            prefixIcon: Icon(
                              _isAdjustment
                                  ? Icons.tune_rounded
                                  : Icons.numbers_rounded,
                            ),
                            helperText: _quantityHelperText(),
                          ),
                          validator: _validateQuantity,
                        ),
                        if (_isAdjustment) ...[
                          const SizedBox(height: 14),
                          _AdjustmentPreview(
                            currentStock: widget.sparePart.currentStock,
                            difference: _adjustmentDifference,
                            unit: widget.sparePart.unit,
                          ),
                        ],
                        if (_isIssue &&
                            _enteredQuantity != null &&
                            _enteredQuantity! >
                                widget.sparePart.currentStock) ...[
                          const SizedBox(height: 14),
                          _WarningBox(
                            message:
                                'Only ${widget.sparePart.currentStock} '
                                '${_formatUnit(widget.sparePart.unit)} '
                                'are currently available.',
                          ),
                        ],
                        if (_isStockIn) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _referenceController,
                            enabled: !_isSaving,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Purchase reference',
                              hintText:
                                  'Invoice number, supplier bill or receipt',
                              prefixIcon: Icon(Icons.receipt_long_outlined),
                              counterText: '',
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _remarksController,
                          enabled: !_isSaving,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: _isAdjustment
                                ? 'Adjustment reason *'
                                : 'Remarks',
                            hintText: _isAdjustment
                                ? 'Explain why the physical and system stock differ'
                                : 'Add optional transaction notes',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 46),
                              child: Icon(Icons.notes_rounded),
                            ),
                          ),
                          validator: (value) {
                            if (!_isAdjustment) {
                              return null;
                            }

                            final text = value?.trim() ?? '';

                            if (text.length < 3) {
                              return 'Enter an adjustment reason of at least 3 characters.';
                            }

                            return null;
                          },
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _errorMessage == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  key: ValueKey(_errorMessage),
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _ErrorBox(message: _errorMessage!),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _TransactionActions(
                isSaving: _isSaving,
                submitLabel: _submitLabel(widget.mode),
                submitIcon: _dialogIcon(widget.mode),
                onCancel: _close,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateQuantity(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return _isAdjustment
          ? 'New stock quantity is required.'
          : 'Quantity is required.';
    }

    final quantity = int.tryParse(text);

    if (quantity == null) {
      return 'Enter a valid whole number.';
    }

    if (_isAdjustment) {
      if (quantity < 0) {
        return 'Stock cannot be negative.';
      }

      return null;
    }

    if (quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    if (_isIssue && quantity > widget.sparePart.currentStock) {
      return 'Insufficient stock. Available: '
          '${widget.sparePart.currentStock}.';
    }

    return null;
  }

  String _quantityHelperText() {
    if (_isAdjustment) {
      return 'Current stock: '
          '${widget.sparePart.currentStock} '
          '${_formatUnit(widget.sparePart.unit)}';
    }

    if (_isIssue) {
      return 'Available to issue: '
          '${widget.sparePart.currentStock} '
          '${_formatUnit(widget.sparePart.unit)}';
    }

    if (widget.mode == StockTransactionMode.stockReturn) {
      return 'The backend will validate the maximum returnable quantity.';
    }

    return 'Quantity will be added to the current stock.';
  }
}

class _TransactionHeader extends StatelessWidget {
  const _TransactionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSaving,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSaving;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: isSaving ? null : onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _PartSummaryCard extends StatelessWidget {
  const _PartSummaryCard({required this.sparePart});

  final SparePart sparePart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final stockColor = sparePart.isOutOfStock
        ? colorScheme.error
        : sparePart.isLowStock
        ? Colors.orange.shade800
        : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.precision_manufacturing_outlined,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sparePart.partName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sparePart.partCode} • '
                  '${sparePart.displayBrand} • '
                  '${sparePart.displayCategory}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${sparePart.currentStock}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: stockColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _formatUnit(sparePart.unit),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustmentPreview extends StatelessWidget {
  const _AdjustmentPreview({
    required this.currentStock,
    required this.difference,
    required this.unit,
  });

  final int currentStock;
  final int difference;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final differenceText = difference > 0
        ? '+$difference'
        : difference.toString();

    final differenceColor = difference > 0
        ? Colors.green.shade700
        : difference < 0
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'System quantity: $currentStock '
              '${_formatUnit(unit)}',
            ),
          ),
          Text(
            'Change $differenceText',
            style: theme.textTheme.labelLarge?.copyWith(
              color: differenceColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionActions extends StatelessWidget {
  const _TransactionActions({
    required this.isSaving,
    required this.submitLabel,
    required this.submitIcon,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isSaving;
  final String submitLabel;
  final IconData submitIcon;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: isSaving ? null : onCancel,
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: isSaving ? null : onSubmit,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(submitIcon),
            label: Text(isSaving ? 'Saving...' : submitLabel),
          ),
        ],
      ),
    );
  }
}

String _dialogTitle(StockTransactionMode mode) {
  switch (mode) {
    case StockTransactionMode.stockIn:
      return 'Stock In';
    case StockTransactionMode.issue:
      return 'Issue Spare Part';
    case StockTransactionMode.stockReturn:
      return 'Return Spare Part';
    case StockTransactionMode.adjustment:
      return 'Adjust Stock';
  }
}

String _dialogSubtitle(StockTransactionMode mode) {
  switch (mode) {
    case StockTransactionMode.stockIn:
      return 'Record newly purchased or received inventory';
    case StockTransactionMode.issue:
      return 'Issue stock to an active repair job';
    case StockTransactionMode.stockReturn:
      return 'Return unused stock from a job card';
    case StockTransactionMode.adjustment:
      return 'Correct the system stock after physical verification';
  }
}

String _submitLabel(StockTransactionMode mode) {
  switch (mode) {
    case StockTransactionMode.stockIn:
      return 'Add Stock';
    case StockTransactionMode.issue:
      return 'Issue Part';
    case StockTransactionMode.stockReturn:
      return 'Return Part';
    case StockTransactionMode.adjustment:
      return 'Save Adjustment';
  }
}

IconData _dialogIcon(StockTransactionMode mode) {
  switch (mode) {
    case StockTransactionMode.stockIn:
      return Icons.add_business_rounded;
    case StockTransactionMode.issue:
      return Icons.outbox_rounded;
    case StockTransactionMode.stockReturn:
      return Icons.assignment_return_rounded;
    case StockTransactionMode.adjustment:
      return Icons.tune_rounded;
  }
}

String _formatStatus(String status) {
  return status
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) =>
            '${word[0].toUpperCase()}'
            '${word.substring(1)}',
      )
      .join(' ');
}

String _formatUnit(String unit) {
  final normalized = unit.trim().toLowerCase();

  if (normalized.isEmpty) {
    return 'units';
  }

  return normalized.replaceAll('_', ' ');
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
