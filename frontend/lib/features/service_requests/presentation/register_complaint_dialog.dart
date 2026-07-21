import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/service_request_model.dart';
import '../data/service_request_provider.dart';

typedef RegisterComplaintCallback =
    Future<void> Function(RegisterComplaintInput input);

class RegisterComplaintDialog extends ConsumerStatefulWidget {
  const RegisterComplaintDialog({required this.onRegister, super.key});

  final RegisterComplaintCallback onRegister;

  @override
  ConsumerState<RegisterComplaintDialog> createState() =>
      _RegisterComplaintDialogState();
}

class _RegisterComplaintDialogState
    extends ConsumerState<RegisterComplaintDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _alternateMobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _pincodeController;

  late final TextEditingController _brandController;
  late final TextEditingController _productNameController;
  late final TextEditingController _modelNumberController;
  late final TextEditingController _serialNumberController;
  late final TextEditingController _purchaseDateController;

  late final TextEditingController _descriptionController;
  late final TextEditingController _accessoriesController;
  late final TextEditingController _deliveryController;

  DateTime? _purchaseDate;
  DateTime? _estimatedDelivery;

  String _warrantyStatus = 'OUT';
  String? _complaintCategory;
  String? _productCondition = 'GOOD';
  String? _priority = 'NORMAL';

  bool _isSaving = false;
  bool _hasSubmitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _fullNameController = TextEditingController();
    _mobileController = TextEditingController();
    _alternateMobileController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _pincodeController = TextEditingController();

    _brandController = TextEditingController();
    _productNameController = TextEditingController();
    _modelNumberController = TextEditingController();
    _serialNumberController = TextEditingController();
    _purchaseDateController = TextEditingController();

    _descriptionController = TextEditingController();
    _accessoriesController = TextEditingController();
    _deliveryController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();

    _brandController.dispose();
    _productNameController.dispose();
    _modelNumberController.dispose();
    _serialNumberController.dispose();
    _purchaseDateController.dispose();

    _descriptionController.dispose();
    _accessoriesController.dispose();
    _deliveryController.dispose();

    super.dispose();
  }

  Future<void> _selectPurchaseDate() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _purchaseDate = selectedDate;
      _purchaseDateController.text = _formatDate(selectedDate);
    });
  }

  Future<void> _selectEstimatedDelivery() async {
    final now = DateTime.now();

    final initialDate = _estimatedDelivery ?? now.add(const Duration(days: 1));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final initialTime = _estimatedDelivery == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay.fromDateTime(_estimatedDelivery!);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (!mounted) {
      return;
    }

    final time = selectedTime ?? initialTime;

    final dateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _estimatedDelivery = dateTime;
      _deliveryController.text = _formatDateTime(dateTime);
    });
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_hasSubmitted) {
      setState(() {
        _hasSubmitted = true;
      });
    }

    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (_complaintCategory == null ||
        _productCondition == null ||
        _priority == null) {
      setState(() {
        _errorMessage = 'Select all required complaint options.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final input = RegisterComplaintInput(
        customer: ComplaintCustomerInput(
          fullName: _fullNameController.text,
          mobile: _mobileController.text,
          alternateMobile: _alternateMobileController.text,
          email: _emailController.text,
          address: _addressController.text,
          city: _cityController.text,
          pincode: _pincodeController.text,
        ),
        product: ComplaintProductInput(
          brand: _brandController.text,
          productName: _productNameController.text,
          modelNumber: _modelNumberController.text,
          serialNumber: _serialNumberController.text,
          purchaseDate: _purchaseDate,
          warrantyStatus: _warrantyStatus,
        ),
        complaint: ComplaintDetailsInput(
          complaintCategory: _complaintCategory!,
          complaintDescription: _descriptionController.text,
          receivedAccessories: _accessoriesController.text,
          productCondition: _productCondition!,
          priority: _priority!,
          estimatedDelivery: _estimatedDelivery,
        ),
      );

      await widget.onRegister(input);

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
    final categoriesState = ref.watch(
      masterOptionsProvider('COMPLAINT_CATEGORY'),
    );

    final conditionsState = ref.watch(
      masterOptionsProvider('PRODUCT_CONDITION'),
    );

    final prioritiesState = ref.watch(masterOptionsProvider('PRIORITY'));

    final screenSize = MediaQuery.sizeOf(context);

    final width = screenSize.width < 980 ? screenSize.width - 28 : 920.0;

    final height = screenSize.height < 900 ? screenSize.height - 28 : 860.0;

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(14),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              _ComplaintHeader(isSaving: _isSaving, onClose: _close),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _hasSubmitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 350),
                      tween: Tween<double>(begin: 0, end: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, animation, child) {
                        return Opacity(
                          opacity: animation,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - animation)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          _SectionCard(
                            icon: Icons.person_outline_rounded,
                            title: 'Customer Details',
                            subtitle:
                                'Enter the customer information received during the call, WhatsApp message or walk-in.',
                            child: _buildCustomerSection(),
                          ),
                          const SizedBox(height: 18),
                          _SectionCard(
                            icon: Icons.devices_other_outlined,
                            title: 'Product Details',
                            subtitle:
                                'Register the appliance along with this complaint. Serial number helps reuse the same product later.',
                            child: _buildProductSection(),
                          ),
                          const SizedBox(height: 18),
                          _SectionCard(
                            icon: Icons.build_circle_outlined,
                            title: 'Complaint Details',
                            subtitle:
                                'Record the problem, condition, priority and expected delivery.',
                            child: _buildComplaintSection(
                              categoriesState: categoriesState,
                              conditionsState: conditionsState,
                              prioritiesState: prioritiesState,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _errorMessage == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    key: ValueKey(_errorMessage),
                                    padding: const EdgeInsets.only(top: 18),
                                    child: _ErrorBox(message: _errorMessage!),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _ComplaintActions(
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

  Widget _buildCustomerSection() {
    return Column(
      children: [
        _ResponsivePair(
          first: TextFormField(
            controller: _mobileController,
            enabled: !_isSaving,
            autofocus: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number *',
              prefixText: '+91 ',
              hintText: 'Customer mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText:
                  'Existing customers are automatically matched by mobile number.',
            ),
            validator: _validateMobile,
          ),
          second: TextFormField(
            controller: _fullNameController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Customer name *',
              hintText: 'Full customer name',
              prefixIcon: Icon(Icons.badge_outlined),
              counterText: '',
            ),
            validator: (value) {
              return _validateRequiredText(
                value,
                label: 'Customer name',
                minimumLength: 2,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _ResponsivePair(
          first: TextFormField(
            controller: _alternateMobileController,
            enabled: !_isSaving,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Alternate mobile',
              prefixText: '+91 ',
              prefixIcon: Icon(Icons.phone_android_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return null;
              }

              return _validateMobile(value);
            },
          ),
          second: TextFormField(
            controller: _emailController,
            enabled: !_isSaving,
            keyboardType: TextInputType.emailAddress,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              counterText: '',
            ),
            validator: _validateEmail,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          enabled: !_isSaving,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 255,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Address',
            hintText: 'House number, street and area',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Icon(Icons.location_on_outlined),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ResponsivePair(
          first: TextFormField(
            controller: _cityController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'City',
              prefixIcon: Icon(Icons.location_city_outlined),
              counterText: '',
            ),
          ),
          second: TextFormField(
            controller: _pincodeController,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Pincode',
              prefixIcon: Icon(Icons.pin_drop_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return null;
              }

              if (text.length < 4) {
                return 'Enter a valid pincode.';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductSection() {
    return Column(
      children: [
        _ResponsivePair(
          first: TextFormField(
            controller: _brandController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Brand *',
              hintText: 'Example: Pigeon',
              prefixIcon: Icon(Icons.verified_outlined),
              counterText: '',
            ),
            validator: (value) {
              return _validateRequiredText(value, label: 'Brand');
            },
          ),
          second: TextFormField(
            controller: _productNameController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Product name/type *',
              hintText: 'Example: Mixer Grinder',
              prefixIcon: Icon(Icons.kitchen_outlined),
              counterText: '',
            ),
            validator: (value) {
              return _validateRequiredText(value, label: 'Product name');
            },
          ),
        ),
        const SizedBox(height: 16),
        _ResponsivePair(
          first: TextFormField(
            controller: _modelNumberController,
            enabled: !_isSaving,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Model number',
              prefixIcon: Icon(Icons.numbers_outlined),
              counterText: '',
            ),
          ),
          second: TextFormField(
            controller: _serialNumberController,
            enabled: !_isSaving,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Serial number',
              prefixIcon: Icon(Icons.qr_code_outlined),
              helperText: 'Used to identify an already registered product.',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ResponsivePair(
          first: TextFormField(
            controller: _purchaseDateController,
            enabled: !_isSaving,
            readOnly: true,
            onTap: _isSaving ? null : _selectPurchaseDate,
            decoration: InputDecoration(
              labelText: 'Purchase date',
              hintText: 'Select date',
              prefixIcon: const Icon(Icons.event_outlined),
              suffixIcon: _purchaseDate == null
                  ? const Icon(Icons.calendar_month_outlined)
                  : IconButton(
                      tooltip: 'Clear purchase date',
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _purchaseDate = null;
                                _purchaseDateController.clear();
                              });
                            },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          second: DropdownButtonFormField<String>(
            initialValue: _warrantyStatus,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Warranty status *',
              prefixIcon: Icon(Icons.workspace_premium_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'IN', child: Text('In Warranty')),
              DropdownMenuItem(value: 'OUT', child: Text('Out of Warranty')),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _warrantyStatus = value;
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintSection({
    required AsyncValue<List<MasterOption>> categoriesState,
    required AsyncValue<List<MasterOption>> conditionsState,
    required AsyncValue<List<MasterOption>> prioritiesState,
  }) {
    return Column(
      children: [
        _buildOptionField(
          label: 'Complaint category *',
          icon: Icons.category_outlined,
          optionType: 'COMPLAINT_CATEGORY',
          state: categoriesState,
          selectedValue: _complaintCategory,
          onChanged: (value) {
            setState(() {
              _complaintCategory = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          enabled: !_isSaving,
          textCapitalization: TextCapitalization.sentences,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Problem description *',
            hintText: 'Explain the issue reported by the customer',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 72),
              child: Icon(Icons.description_outlined),
            ),
          ),
          validator: (value) {
            return _validateRequiredText(
              value,
              label: 'Problem description',
              minimumLength: 3,
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _accessoriesController,
          enabled: !_isSaving,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Received accessories',
            hintText: 'Example: Jar, remote or power cable',
            prefixIcon: Icon(Icons.cable_rounded),
          ),
        ),
        const SizedBox(height: 16),
        _ResponsivePair(
          first: _buildOptionField(
            label: 'Product condition *',
            icon: Icons.fact_check_outlined,
            optionType: 'PRODUCT_CONDITION',
            state: conditionsState,
            selectedValue: _productCondition,
            onChanged: (value) {
              setState(() {
                _productCondition = value;
              });
            },
          ),
          second: _buildOptionField(
            label: 'Priority *',
            icon: Icons.priority_high_rounded,
            optionType: 'PRIORITY',
            state: prioritiesState,
            selectedValue: _priority,
            onChanged: (value) {
              setState(() {
                _priority = value;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deliveryController,
          enabled: !_isSaving,
          readOnly: true,
          onTap: _isSaving ? null : _selectEstimatedDelivery,
          decoration: InputDecoration(
            labelText: 'Estimated delivery',
            hintText: 'Select date and time',
            prefixIcon: const Icon(Icons.event_available_outlined),
            suffixIcon: _estimatedDelivery == null
                ? const Icon(Icons.calendar_month_outlined)
                : IconButton(
                    tooltip: 'Clear estimated delivery',
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _estimatedDelivery = null;

                              _deliveryController.clear();
                            });
                          },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionField({
    required String label,
    required IconData icon,
    required String optionType,
    required AsyncValue<List<MasterOption>> state,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return state.when(
      data: (options) {
        final availableOptions = [...options];

        if (selectedValue != null &&
            selectedValue.isNotEmpty &&
            !availableOptions.any((option) => option.code == selectedValue)) {
          availableOptions.insert(
            0,
            MasterOption(
              id: 0,
              optionType: optionType,
              code: selectedValue,
              label: _formatStatus(selectedValue),
              displayOrder: 0,
              isActive: true,
            ),
          );
        }

        if (availableOptions.isEmpty) {
          return _RetryField(
            label: 'No $label options found',
            icon: icon,
            onRetry: () {
              ref.invalidate(masterOptionsProvider(optionType));
            },
          );
        }

        return DropdownButtonFormField<String>(
          key: ValueKey(
            '$optionType-$selectedValue-'
            '${availableOptions.length}',
          ),
          initialValue: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          items: availableOptions
              .map((option) {
                return DropdownMenuItem<String>(
                  value: option.code,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                );
              })
              .toList(growable: false),
          onChanged: _isSaving ? null : onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Select $label.';
            }

            return null;
          },
        );
      },
      loading: () => _LoadingField(label: 'Loading $label...', icon: icon),
      error: (error, stackTrace) {
        return _RetryField(
          label: 'Unable to load $label',
          icon: icon,
          onRetry: () {
            ref.invalidate(masterOptionsProvider(optionType));
          },
        );
      },
    );
  }
}

class _ComplaintHeader extends StatelessWidget {
  const _ComplaintHeader({required this.isSaving, required this.onClose});

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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Register Customer Complaint',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Customer, product and complaint details in one workflow.',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
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
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
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

class _ComplaintActions extends StatelessWidget {
  const _ComplaintActions({
    required this.isSaving,
    required this.onCancel,
    required this.onSubmit,
  });

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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_task_rounded),
            label: Text(isSaving ? 'Registering...' : 'Register Complaint'),
          ),
        ],
      ),
    );
  }
}

class _LoadingField extends StatelessWidget {
  const _LoadingField({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _RetryField extends StatelessWidget {
  const _RetryField({
    required this.label,
    required this.icon,
    required this.onRetry,
  });

  final String label;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: 'Retry',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 11),
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

String? _validateRequiredText(
  String? value, {
  required String label,
  int minimumLength = 1,
}) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return '$label is required.';
  }

  if (text.length < minimumLength) {
    return '$label must contain at least '
        '$minimumLength characters.';
  }

  return null;
}

String? _validateMobile(String? value) {
  final mobile = value?.trim() ?? '';

  if (mobile.isEmpty) {
    return 'Mobile number is required.';
  }

  if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
    return 'Enter a 10 digit mobile number.';
  }

  return null;
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';

  if (email.isEmpty) {
    return null;
  }

  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  if (!valid) {
    return 'Enter a valid email address.';
  }

  return null;
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');

  final month = value.month.toString().padLeft(2, '0');

  return '$day/$month/${value.year}';
}

String _formatDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');

  final minute = value.minute.toString().padLeft(2, '0');

  return '${_formatDate(value)} $hour:$minute';
}

String _formatStatus(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) {
        return '${word[0].toUpperCase()}'
            '${word.substring(1)}';
      })
      .join(' ');
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
