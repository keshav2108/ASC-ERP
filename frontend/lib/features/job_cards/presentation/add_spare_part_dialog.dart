import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_provider.dart';
import '../../inventory/data/inventory_model.dart';
import '../../inventory/data/inventory_provider.dart';
import '../data/job_card_provider.dart';

class AddSparePartDialog extends ConsumerStatefulWidget {
  const AddSparePartDialog({
    required this.jobCardId,
    required this.jobCardCode,
    super.key,
  });

  final int jobCardId;
  final String jobCardCode;

  @override
  ConsumerState<AddSparePartDialog> createState() => _AddSparePartDialogState();
}

class _AddSparePartDialogState extends ConsumerState<AddSparePartDialog> {
  final _formKey = GlobalKey<FormState>();

  final _partSearchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _remarksController = TextEditingController();

  SparePart? _selectedPart;
  Key _partPickerKey = UniqueKey();

  bool _isSubmitting = false;
  bool _didIssueAnyPart = false;
  String? _errorMessage;

  int get _quantity {
    return int.tryParse(_quantityController.text.trim()) ?? 0;
  }

  double get _lineTotal {
    return (_selectedPart?.sellingPrice ?? 0) * _quantity;
  }

  @override
  void dispose() {
    _partSearchController.dispose();
    _quantityController.dispose();
    _remarksController.dispose();

    super.dispose();
  }

  Future<void> _issueSelectedPart() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (_selectedPart == null) {
      setState(() {
        _errorMessage = 'Select a spare part before adding it.';
      });

      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final selectedPart = _selectedPart!;
    final quantity = _quantity;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(stockTransactionProvider.notifier)
          .issueStockToJobCard(
            StockIssueInput(
              sparePartId: selectedPart.id,
              jobCardId: widget.jobCardId,
              quantity: quantity,
              remarks: _remarksController.text,
            ),
          );

      // Phase 4: Refresh Job Card so workflow dialog sees updated status/parts
      ref.invalidate(jobCardProvider);
      ref.invalidate(dashboardProvider);

      if (!mounted) {
        return;
      }

      setState(() {
        _didIssueAnyPart = true;
        _selectedPart = null;
        _partPickerKey = UniqueKey();
        _partSearchController.clear();
        _quantityController.text = '1';
        _remarksController.clear();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${selectedPart.partName} added to '
              '${widget.jobCardCode}.',
            ),
          ),
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
          _isSubmitting = false;
        });
      }
    }
  }

  void _closeDialog() {
    if (_isSubmitting) {
      return;
    }

    Navigator.of(context).pop(_didIssueAnyPart);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final partsState = ref.watch(sparePartProvider);

    final transactionsState = ref.watch(
      jobCardTransactionsProvider(widget.jobCardId),
    );

    final screenSize = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 980,
            maxHeight: screenSize.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(
                jobCardCode: widget.jobCardCode,
                isBusy: _isSubmitting,
                onClose: _closeDialog,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useTwoColumns = constraints.maxWidth >= 760;

                      final issuePanel = _buildIssuePanel(
                        theme,
                        colorScheme,
                        partsState,
                      );

                      final usedPartsPanel = _buildUsedPartsPanel(
                        theme,
                        colorScheme,
                        transactionsState,
                      );

                      if (!useTwoColumns) {
                        return Column(
                          children: [
                            issuePanel,
                            const SizedBox(height: 18),
                            usedPartsPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: issuePanel),
                          const SizedBox(width: 18),
                          Expanded(child: usedPartsPanel),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssuePanel(
    ThemeData theme,
    ColorScheme colorScheme,
    AsyncValue<List<SparePart>> partsState,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PanelIcon(
                  icon: Icons.add_shopping_cart_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Spare Part',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select a part and quantity. The dialog stays open '
              'so multiple parts can be added.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            partsState.when(
              loading: () {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              error: (error, stackTrace) {
                return _InlineMessage(
                  icon: Icons.error_outline_rounded,
                  message: _cleanError(error),
                  color: colorScheme.error,
                );
              },
              data: (parts) {
                final availableParts = parts
                    .where((part) => part.isActive && part.hasAvailableStock)
                    .toList(growable: false);

                if (availableParts.isEmpty) {
                  return _InlineMessage(
                    icon: Icons.inventory_2_outlined,
                    message:
                        'No active spare part currently has stock available.',
                    color: colorScheme.error,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return DropdownMenu<SparePart>(
                      key: _partPickerKey,
                      controller: _partSearchController,
                      width: constraints.maxWidth,
                      enabled: !_isSubmitting,
                      enableFilter: true,
                      enableSearch: true,
                      requestFocusOnTap: true,
                      menuHeight: 320,
                      label: const Text('Search spare part'),
                      hintText: 'Part code, name or brand',
                      leadingIcon: const Icon(Icons.search_rounded),
                      dropdownMenuEntries: availableParts
                          .map(
                            (part) => DropdownMenuEntry<SparePart>(
                              value: part,
                              label: '${part.partCode} • ${part.partName}',
                              trailingIcon: Text(
                                '${part.currentStock} ${part.unit}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (part) {
                        setState(() {
                          _selectedPart = part;
                          _errorMessage = null;
                        });
                      },
                    );
                  },
                );
              },
            ),
            if (_selectedPart != null) ...[
              const SizedBox(height: 14),
              _SelectedPartCard(part: _selectedPart!),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
              onChanged: (_) {
                setState(() {});
              },
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');

                if (quantity == null || quantity <= 0) {
                  return 'Enter a quantity greater than zero.';
                }

                final selectedPart = _selectedPart;

                if (selectedPart != null &&
                    quantity > selectedPart.currentStock) {
                  return 'Only ${selectedPart.currentStock} '
                      '${selectedPart.unit} available.';
                }

                return null;
              },
              onFieldSubmitted: (_) {
                _issueSelectedPart();
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksController,
              enabled: !_isSubmitting,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                hintText: 'Where or why this part was used',
                prefixIcon: Icon(Icons.notes_rounded),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _LineTotalCard(
              unitPrice: _selectedPart?.sellingPrice ?? 0,
              quantity: _quantity,
              total: _lineTotal,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _InlineMessage(
                icon: Icons.error_outline_rounded,
                message: _errorMessage!,
                color: colorScheme.error,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _issueSelectedPart,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline_rounded),
                label: Text(
                  _isSubmitting ? 'Adding Part...' : 'Add Part to Job Card',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsedPartsPanel(
    ThemeData theme,
    ColorScheme colorScheme,
    AsyncValue<List<StockTransaction>> transactionsState,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PanelIcon(
                icon: Icons.build_circle_outlined,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Parts Already Added',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'These parts will automatically be included when '
            'the invoice is generated.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          transactionsState.when(
            loading: () {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              );
            },
            error: (error, stackTrace) {
              return _InlineMessage(
                icon: Icons.error_outline_rounded,
                message: _cleanError(error),
                color: colorScheme.error,
              );
            },
            data: (transactions) {
              final summaries = _summarizeIssuedParts(transactions);

              if (summaries.isEmpty) {
                return _InlineMessage(
                  icon: Icons.inventory_2_outlined,
                  message: 'No spare part has been added to this Job Card yet.',
                  color: colorScheme.primary,
                );
              }

              final grandTotal = summaries.fold<double>(
                0,
                (total, item) => total + item.total,
              );

              return Column(
                children: [
                  ...summaries.map(
                    (summary) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _IssuedPartTile(summary: summary),
                    ),
                  ),
                  const Divider(height: 26),
                  Row(
                    children: [
                      Text(
                        'Parts Total',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatMoney(grandTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.jobCardCode,
    required this.isBusy,
    required this.onClose,
  });

  final String jobCardCode;
  final bool isBusy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _PanelIcon(icon: Icons.build_rounded, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job Card Spare Parts',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jobCardCode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: isBusy ? null : onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SelectedPartCard extends StatelessWidget {
  const _SelectedPartCard({required this.part});

  final SparePart part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            part.partName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${part.partCode} • ${part.displayBrand}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.inventory_2_outlined,
                label: '${part.currentStock} ${part.unit} available',
              ),
              _InfoChip(
                icon: Icons.currency_rupee_rounded,
                label: '${part.sellingPrice.toStringAsFixed(2)} each',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineTotalCard extends StatelessWidget {
  const _LineTotalCard({
    required this.unitPrice,
    required this.quantity,
    required this.total,
  });

  final double unitPrice;
  final int quantity;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _AmountRow(label: 'Unit price', value: _formatMoney(unitPrice)),
          const SizedBox(height: 8),
          _AmountRow(
            label: 'Quantity',
            value: quantity > 0 ? '$quantity' : '0',
          ),
          const Divider(height: 22),
          _AmountRow(
            label: 'Line total',
            value: _formatMoney(total),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: emphasized
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }
}

class _IssuedPartTile extends StatelessWidget {
  const _IssuedPartTile({required this.summary});

  final _IssuedPartSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelIcon(
            icon: Icons.settings_outlined,
            color: colorScheme.primary,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.part.partName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary.part.partCode,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.quantity} ${summary.part.unit} × '
                  '${_formatMoney(summary.unitPrice)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatMoney(summary.total),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelIcon extends StatelessWidget {
  const _PanelIcon({required this.icon, required this.color, this.size = 42});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssuedPartSummary {
  _IssuedPartSummary({
    required this.part,
    required this.quantity,
    required this.total,
    required this.unitPrice,
  });

  SparePart part;
  int quantity;
  double total;
  double unitPrice;
}

List<_IssuedPartSummary> _summarizeIssuedParts(
  List<StockTransaction> transactions,
) {
  final summaries = <int, _IssuedPartSummary>{};

  for (final transaction in transactions) {
    if (!transaction.isIssue && !transaction.isReturn) {
      continue;
    }

    final quantityChange = transaction.isIssue
        ? transaction.quantity
        : -transaction.quantity;

    final valueChange = transaction.isIssue
        ? transaction.lineTotal
        : -transaction.lineTotal;

    final summary = summaries.putIfAbsent(
      transaction.sparePartId,
      () => _IssuedPartSummary(
        part: transaction.sparePart,
        quantity: 0,
        total: 0,
        unitPrice: transaction.unitPrice,
      ),
    );

    summary.part = transaction.sparePart;
    summary.quantity += quantityChange;
    summary.total += valueChange;
    summary.unitPrice = transaction.unitPrice;
  }

  final result = summaries.values
      .where((summary) => summary.quantity > 0)
      .toList(growable: false);

  result.sort(
    (first, second) => first.part.partName.toLowerCase().compareTo(
      second.part.partName.toLowerCase(),
    ),
  );

  return result;
}

String _formatMoney(double amount) {
  return '₹${amount.toStringAsFixed(2)}';
}

String _cleanError(Object error) {
  final message = error.toString().trim();

  return message
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
