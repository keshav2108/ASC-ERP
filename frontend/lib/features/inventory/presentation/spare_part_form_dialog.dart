import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/inventory_model.dart';

typedef CreateSparePartCallback =
    Future<void> Function(SparePartCreateInput input);

typedef UpdateSparePartCallback =
    Future<void> Function(SparePartUpdateInput input);

class SparePartFormDialog extends StatefulWidget {
  const SparePartFormDialog._({
    required this._mode,
    required this.onCreate,
    required this.onUpdate,
    this.sparePart,
  });

  factory SparePartFormDialog.create({
    required CreateSparePartCallback onCreate,
  }) {
    return SparePartFormDialog._(
      mode: _SparePartFormMode.create,
      onCreate: onCreate,
      onUpdate: null,
    );
  }

  factory SparePartFormDialog.edit({
    required SparePart sparePart,
    required UpdateSparePartCallback onUpdate,
  }) {
    return SparePartFormDialog._(
      mode: _SparePartFormMode.edit,
      sparePart: sparePart,
      onCreate: null,
      onUpdate: onUpdate,
    );
  }

  final _SparePartFormMode _mode;
  final SparePart? sparePart;
  final CreateSparePartCallback? onCreate;
  final UpdateSparePartCallback? onUpdate;

  bool get isEditing {
    return _mode == _SparePartFormMode.edit;
  }

  @override
  State<SparePartFormDialog> createState() => _SparePartFormDialogState();
}

class _SparePartFormDialogState extends State<SparePartFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _partNameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _currentStockController;
  late final TextEditingController _minimumStockController;

  static const List<String> _units = <String>[
    'PIECE',
    'SET',
    'PAIR',
    'BOX',
    'PACK',
    'METER',
    'LITRE',
    'KILOGRAM',
  ];

  String _selectedUnit = 'PIECE';
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing {
    return widget.isEditing;
  }

  @override
  void initState() {
    super.initState();

    final sparePart = widget.sparePart;

    _partNameController = TextEditingController(
      text: sparePart?.partName ?? '',
    );

    _brandController = TextEditingController(text: sparePart?.brand ?? '');

    _categoryController = TextEditingController(
      text: sparePart?.productCategory ?? '',
    );

    _purchasePriceController = TextEditingController(
      text: sparePart == null ? '' : _decimalText(sparePart.purchasePrice),
    );

    _sellingPriceController = TextEditingController(
      text: sparePart == null ? '' : _decimalText(sparePart.sellingPrice),
    );

    _currentStockController = TextEditingController(
      text: sparePart?.currentStock.toString() ?? '0',
    );

    _minimumStockController = TextEditingController(
      text: sparePart?.minimumStock.toString() ?? '0',
    );

    final currentUnit = sparePart?.normalizedUnit ?? 'PIECE';

    _selectedUnit = _units.contains(currentUnit) ? currentUnit : 'PIECE';
  }

  @override
  void dispose() {
    _partNameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _currentStockController.dispose();
    _minimumStockController.dispose();

    super.dispose();
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
      if (_isEditing) {
        await widget.onUpdate!(
          SparePartUpdateInput(
            partName: _partNameController.text.trim(),
            brand: _brandController.text.trim(),
            productCategory: _categoryController.text.trim(),
            unit: _selectedUnit,
            purchasePrice: double.parse(_purchasePriceController.text.trim()),
            sellingPrice: double.parse(_sellingPriceController.text.trim()),
            minimumStock: int.parse(_minimumStockController.text.trim()),
            includeBrand: true,
            includeProductCategory: true,
          ),
        );
      } else {
        await widget.onCreate!(
          SparePartCreateInput(
            partName: _partNameController.text.trim(),
            brand: _brandController.text.trim(),
            productCategory: _categoryController.text.trim(),
            unit: _selectedUnit,
            purchasePrice: double.parse(_purchasePriceController.text.trim()),
            sellingPrice: double.parse(_sellingPriceController.text.trim()),
            currentStock: int.parse(_currentStockController.text.trim()),
            minimumStock: int.parse(_minimumStockController.text.trim()),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);

    final dialogWidth = screenSize.width < 700 ? screenSize.width - 32 : 680.0;

    final dialogHeight = screenSize.height < 760
        ? screenSize.height - 32
        : 720.0;

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
              _DialogHeader(
                isEditing: _isEditing,
                partCode: widget.sparePart?.partCode,
                isSaving: _isSaving,
                onClose: _close,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 320),
                      tween: Tween<double>(begin: 0, end: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, animation, child) {
                        return Opacity(
                          opacity: animation,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - animation)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeading(
                            icon: Icons.settings_suggest_rounded,
                            title: 'Part information',
                            subtitle:
                                'Enter the identity and appliance details for this spare part.',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _partNameController,
                            enabled: !_isSaving,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 150,
                            decoration: const InputDecoration(
                              labelText: 'Part name *',
                              hintText: 'Example: Mixer motor',
                              prefixIcon: Icon(Icons.build_circle_outlined),
                              counterText: '',
                            ),
                            validator: _validatePartName,
                          ),
                          const SizedBox(height: 16),
                          _ResponsiveFields(
                            first: TextFormField(
                              controller: _brandController,
                              enabled: !_isSaving,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'Brand',
                                hintText: 'Example: Pigeon',
                                prefixIcon: Icon(Icons.verified_outlined),
                                counterText: '',
                              ),
                            ),
                            second: TextFormField(
                              controller: _categoryController,
                              enabled: !_isSaving,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'Product category',
                                hintText: 'Example: Mixer',
                                prefixIcon: Icon(Icons.category_outlined),
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unit *',
                              prefixIcon: Icon(Icons.straighten_rounded),
                            ),
                            items: _units.map((unit) {
                              return DropdownMenuItem<String>(
                                value: unit,
                                child: Text(_formatUnit(unit)),
                              );
                            }).toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _selectedUnit = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 28),
                          _SectionHeading(
                            icon: Icons.currency_rupee_rounded,
                            title: 'Pricing',
                            subtitle:
                                'Purchase price is used for stock value; selling price is used when issuing parts.',
                          ),
                          const SizedBox(height: 16),
                          _ResponsiveFields(
                            first: TextFormField(
                              controller: _purchasePriceController,
                              enabled: !_isSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [_decimalFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Purchase price *',
                                hintText: '0.00',
                                prefixText: '₹ ',
                              ),
                              validator: (value) {
                                return _validatePrice(value, 'Purchase price');
                              },
                            ),
                            second: TextFormField(
                              controller: _sellingPriceController,
                              enabled: !_isSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [_decimalFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Selling price *',
                                hintText: '0.00',
                                prefixText: '₹ ',
                              ),
                              validator: (value) {
                                return _validatePrice(value, 'Selling price');
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          _SectionHeading(
                            icon: Icons.inventory_2_outlined,
                            title: 'Stock settings',
                            subtitle: _isEditing
                                ? 'Use stock transactions to change current quantity. Update the alert threshold here.'
                                : 'Set opening stock and the minimum quantity that triggers a low-stock alert.',
                          ),
                          const SizedBox(height: 16),
                          _ResponsiveFields(
                            first: TextFormField(
                              controller: _currentStockController,
                              enabled: !_isEditing && !_isSaving,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: _isEditing
                                    ? 'Current stock'
                                    : 'Opening stock *',
                                prefixIcon: const Icon(Icons.inventory_rounded),
                                helperText: _isEditing
                                    ? 'Change through Stock In or Adjustment'
                                    : null,
                              ),
                              validator: _validateStockQuantity,
                            ),
                            second: TextFormField(
                              controller: _minimumStockController,
                              enabled: !_isSaving,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Minimum stock *',
                                prefixIcon: Icon(
                                  Icons.notification_important_outlined,
                                ),
                                helperText: 'Low-stock alert threshold',
                              ),
                              validator: _validateStockQuantity,
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _errorMessage == null
                                ? const SizedBox.shrink()
                                : Container(
                                    key: ValueKey(_errorMessage),
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onErrorContainer,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _DialogActions(
                isEditing: _isEditing,
                isSaving: _isSaving,
                onCancel: _close,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.isEditing,
    required this.isSaving,
    required this.onClose,
    this.partCode,
  });

  final bool isEditing;
  final bool isSaving;
  final String? partCode;
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
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Spare Part' : 'Add Spare Part',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEditing && partCode != null
                      ? partCode!
                      : 'Create a new inventory item',
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.onSecondaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.isEditing,
    required this.isSaving,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isEditing;
  final bool isSaving;
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
                : Icon(isEditing ? Icons.save_rounded : Icons.add_rounded),
            label: Text(
              isSaving
                  ? 'Saving...'
                  : isEditing
                  ? 'Save Changes'
                  : 'Add Spare Part',
            ),
          ),
        ],
      ),
    );
  }
}

enum _SparePartFormMode { create, edit }

String? _validatePartName(String? value) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return 'Part name is required.';
  }

  if (text.length < 2) {
    return 'Enter at least 2 characters.';
  }

  if (text.length > 150) {
    return 'Part name cannot exceed 150 characters.';
  }

  return null;
}

String? _validatePrice(String? value, String fieldName) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return '$fieldName is required.';
  }

  final price = double.tryParse(text);

  if (price == null) {
    return 'Enter a valid amount.';
  }

  if (price < 0) {
    return '$fieldName cannot be negative.';
  }

  return null;
}

String? _validateStockQuantity(String? value) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return 'Stock quantity is required.';
  }

  final quantity = int.tryParse(text);

  if (quantity == null) {
    return 'Enter a whole number.';
  }

  if (quantity < 0) {
    return 'Quantity cannot be negative.';
  }

  return null;
}

TextInputFormatter _decimalFormatter() {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final isValid = RegExp(r'^\d{0,8}(\.\d{0,2})?$').hasMatch(newValue.text);

    return isValid ? newValue : oldValue;
  });
}

String _formatUnit(String unit) {
  final normalized = unit.trim().toLowerCase().replaceAll('_', ' ');

  if (normalized.isEmpty) {
    return unit;
  }

  return normalized
      .split(' ')
      .map((word) {
        if (word.isEmpty) {
          return word;
        }

        return '${word[0].toUpperCase()}'
            '${word.substring(1)}';
      })
      .join(' ');
}

String _decimalText(double value) {
  return value.toStringAsFixed(2);
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
