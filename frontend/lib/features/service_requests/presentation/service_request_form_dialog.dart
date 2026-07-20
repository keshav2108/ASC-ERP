import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../customers/data/customer_provider.dart';
import '../data/service_request_model.dart';
import '../data/service_request_provider.dart';

class ServiceRequestFormDialog extends ConsumerStatefulWidget {
  const ServiceRequestFormDialog.create({required this.onCreate, super.key})
    : serviceRequest = null,
      onUpdate = null;

  const ServiceRequestFormDialog.edit({
    required this.serviceRequest,
    required this.onUpdate,
    super.key,
  }) : onCreate = null;

  final ServiceRequest? serviceRequest;

  final Future<void> Function(ServiceRequestCreateInput input)? onCreate;

  final Future<void> Function(ServiceRequestUpdateInput input)? onUpdate;

  @override
  ConsumerState<ServiceRequestFormDialog> createState() =>
      _ServiceRequestFormDialogState();
}

class _ServiceRequestFormDialogState
    extends ConsumerState<ServiceRequestFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _accessoriesController;
  late final TextEditingController _deliveryController;

  int? _selectedCustomerId;
  int? _selectedProductId;

  String? _selectedComplaintCategory;
  String? _selectedProductCondition;
  String? _selectedPriority;
  String? _selectedStatus;

  DateTime? _estimatedDelivery;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.serviceRequest != null;

  @override
  void initState() {
    super.initState();

    final request = widget.serviceRequest;

    _selectedCustomerId = request?.customerId;
    _selectedProductId = request?.customerProductId;
    _selectedComplaintCategory = request?.complaintCategory;
    _selectedProductCondition = request?.productCondition;
    _selectedPriority = request?.priority;
    _selectedStatus = request?.status;
    _estimatedDelivery = request?.estimatedDelivery;

    _descriptionController = TextEditingController(
      text: request?.complaintDescription ?? '',
    );

    _accessoriesController = TextEditingController(
      text: request?.receivedAccessories ?? '',
    );

    _deliveryController = TextEditingController(
      text: _formatDateTime(_estimatedDelivery),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _accessoriesController.dispose();
    _deliveryController.dispose();

    super.dispose();
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
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isEditing &&
        (_selectedCustomerId == null || _selectedProductId == null)) {
      setState(() {
        _errorMessage = 'Select a customer and registered product.';
      });
      return;
    }

    if (_selectedComplaintCategory == null ||
        _selectedProductCondition == null ||
        _selectedPriority == null) {
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
      if (_isEditing) {
        await widget.onUpdate!(
          ServiceRequestUpdateInput(
            complaintCategory: _selectedComplaintCategory,
            complaintDescription: _descriptionController.text,
            receivedAccessories: _accessoriesController.text,
            productCondition: _selectedProductCondition,
            priority: _selectedPriority,
            status: _selectedStatus,
            estimatedDelivery: _estimatedDelivery,
          ),
        );
      } else {
        await widget.onCreate!(
          ServiceRequestCreateInput(
            customerId: _selectedCustomerId!,
            customerProductId: _selectedProductId!,
            complaintCategory: _selectedComplaintCategory!,
            complaintDescription: _descriptionController.text,
            receivedAccessories: _accessoriesController.text,
            productCondition: _selectedProductCondition!,
            priority: _selectedPriority!,
            estimatedDelivery: _estimatedDelivery,
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

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customerProvider);

    final categoriesState = ref.watch(
      masterOptionsProvider('COMPLAINT_CATEGORY'),
    );

    final conditionsState = ref.watch(
      masterOptionsProvider('PRODUCT_CONDITION'),
    );

    final prioritiesState = ref.watch(masterOptionsProvider('PRIORITY'));

    final statusesState = ref.watch(masterOptionsProvider('SERVICE_STATUS'));

    final productsState = _selectedCustomerId == null
        ? null
        : ref.watch(customerProductsProvider(_selectedCustomerId!));

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 28),
                if (_isEditing)
                  _buildRequestIdentity()
                else ...[
                  _buildCustomerField(customersState),
                  const SizedBox(height: 16),
                  _buildProductField(productsState),
                ],
                const SizedBox(height: 16),
                _buildOptionField(
                  label: 'Complaint category',
                  icon: Icons.category_outlined,
                  state: categoriesState,
                  selectedValue: _selectedComplaintCategory,
                  onChanged: (value) {
                    setState(() {
                      _selectedComplaintCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Complaint description',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) {
                    final description = value?.trim() ?? '';

                    if (description.isEmpty) {
                      return 'Complaint description is required.';
                    }

                    if (description.length < 3) {
                      return 'Enter at least 3 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accessoriesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Received accessories',
                    hintText: 'Example: Remote, power cable, jar',
                    prefixIcon: Icon(Icons.cable_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final conditionField = _buildOptionField(
                      label: 'Product condition',
                      icon: Icons.fact_check_outlined,
                      state: conditionsState,
                      selectedValue: _selectedProductCondition,
                      onChanged: (value) {
                        setState(() {
                          _selectedProductCondition = value;
                        });
                      },
                    );

                    final priorityField = _buildOptionField(
                      label: 'Priority',
                      icon: Icons.priority_high_rounded,
                      state: prioritiesState,
                      selectedValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value;
                        });
                      },
                    );

                    if (constraints.maxWidth < 560) {
                      return Column(
                        children: [
                          conditionField,
                          const SizedBox(height: 16),
                          priorityField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: conditionField),
                        const SizedBox(width: 16),
                        Expanded(child: priorityField),
                      ],
                    );
                  },
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  _buildOptionField(
                    label: 'Service status',
                    icon: Icons.change_circle_outlined,
                    state: statusesState,
                    selectedValue: _selectedStatus,
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deliveryController,
                  readOnly: true,
                  onTap: _isSaving ? null : _selectEstimatedDelivery,
                  decoration: InputDecoration(
                    labelText: 'Estimated delivery',
                    hintText: 'Select date and time',
                    prefixIcon: const Icon(Icons.event_available_outlined),
                    suffixIcon: _estimatedDelivery == null
                        ? const Icon(Icons.calendar_month_outlined)
                        : IconButton(
                            tooltip: 'Clear date',
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  _ErrorBox(message: _errorMessage!),
                ],
                const SizedBox(height: 28),
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
          child: Icon(
            _isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
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
                _isEditing ? 'Edit Service Request' : 'Create Service Request',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _isEditing
                    ? 'Update complaint and workflow information.'
                    : 'Register a new customer complaint.',
                style: const TextStyle(color: AppColors.textSecondary),
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

  Widget _buildRequestIdentity() {
    final request = widget.serviceRequest!;

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
            request.requestCode,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            request.customer.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.customer.mobile} • '
            '${request.customerProduct.displayName}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerField(AsyncValue customersState) {
    return customersState.when(
      data: (customers) {
        final sortedCustomers = [...customers]
          ..sort(
            (first, second) => first.fullName.toLowerCase().compareTo(
              second.fullName.toLowerCase(),
            ),
          );

        return DropdownButtonFormField<int>(
          key: ValueKey('customer-$_selectedCustomerId'),
          initialValue: _selectedCustomerId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Customer',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: sortedCustomers.map((customer) {
            return DropdownMenuItem<int>(
              value: customer.id,
              child: Text(
                '${customer.fullName} — '
                '${customer.mobile}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _selectedCustomerId = value;
                    _selectedProductId = null;
                    _errorMessage = null;
                  });
                },
          validator: (value) {
            if (value == null) {
              return 'Select a customer.';
            }

            return null;
          },
        );
      },
      loading: () => const _LoadingField(
        label: 'Loading customers...',
        icon: Icons.person_outline_rounded,
      ),
      error: (error, stackTrace) => _ErrorField(
        label: 'Unable to load customers',
        icon: Icons.person_outline_rounded,
        onRetry: () {
          ref.invalidate(customerProvider);
        },
      ),
    );
  }

  Widget _buildProductField(AsyncValue<List<CustomerProduct>>? productsState) {
    if (_selectedCustomerId == null) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Registered product',
          hintText: 'Select a customer first',
          prefixIcon: Icon(Icons.devices_other_outlined),
        ),
      );
    }

    return productsState!.when(
      data: (products) {
        if (products.isEmpty) {
          return TextFormField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Registered product',
              hintText: 'This customer has no registered products',
              prefixIcon: Icon(Icons.devices_other_outlined),
            ),
          );
        }

        final selectedExists = products.any(
          (product) => product.id == _selectedProductId,
        );

        return DropdownButtonFormField<int>(
          key: ValueKey(
            'product-$_selectedCustomerId-'
            '$_selectedProductId',
          ),
          initialValue: selectedExists ? _selectedProductId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Registered product',
            prefixIcon: Icon(Icons.devices_other_outlined),
          ),
          items: products.map((product) {
            return DropdownMenuItem<int>(
              value: product.id,
              child: Text(
                '${product.displayName} • '
                '${_formatStatus(product.warrantyStatus)}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _selectedProductId = value;
                  });
                },
          validator: (value) {
            if (value == null) {
              return 'Select a registered product.';
            }

            return null;
          },
        );
      },
      loading: () => const _LoadingField(
        label: 'Loading products...',
        icon: Icons.devices_other_outlined,
      ),
      error: (error, stackTrace) => _ErrorField(
        label: 'Unable to load products',
        icon: Icons.devices_other_outlined,
        onRetry: () {
          ref.invalidate(customerProductsProvider(_selectedCustomerId!));
        },
      ),
    );
  }

  Widget _buildOptionField({
    required String label,
    required IconData icon,
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
              optionType: '',
              code: selectedValue,
              label: _formatStatus(selectedValue),
              displayOrder: 0,
              isActive: true,
            ),
          );
        }

        return DropdownButtonFormField<String>(
          key: ValueKey(
            '$label-$selectedValue-'
            '${availableOptions.length}',
          ),
          initialValue: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          items: availableOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option.code,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
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
      error: (error, stackTrace) => _ErrorField(
        label: 'Unable to load $label',
        icon: icon,
        onRetry: () {
          ref.invalidate(masterOptionsProvider(_optionTypeForLabel(label)));
        },
      ),
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
              : Icon(_isEditing ? Icons.save_rounded : Icons.add_task_rounded),
          label: Text(
            _isSaving
                ? 'Saving...'
                : _isEditing
                ? 'Save Changes'
                : 'Create Request',
          ),
        ),
      ],
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

class _ErrorField extends StatelessWidget {
  const _ErrorField({
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
        prefixIcon: Icon(icon, color: AppColors.danger),
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

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '';
  }

  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$day/$month/${dateTime.year}  '
      '$hour:$minute';
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

String _optionTypeForLabel(String label) {
  switch (label) {
    case 'Complaint category':
      return 'COMPLAINT_CATEGORY';
    case 'Product condition':
      return 'PRODUCT_CONDITION';
    case 'Priority':
      return 'PRIORITY';
    case 'Service status':
      return 'SERVICE_STATUS';
    default:
      return label.toUpperCase().replaceAll(' ', '_');
  }
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
