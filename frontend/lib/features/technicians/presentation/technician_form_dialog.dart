import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/technician_model.dart';

class TechnicianFormDialog extends StatefulWidget {
  const TechnicianFormDialog._({
    required this.technician,
    required this.onCreate,
    required this.onUpdate,
  });

  factory TechnicianFormDialog.create({
    required Future<void> Function(TechnicianCreateInput input) onCreate,
  }) {
    return TechnicianFormDialog._(
      technician: null,
      onCreate: onCreate,
      onUpdate: null,
    );
  }

  factory TechnicianFormDialog.edit({
    required Technician technician,
    required Future<void> Function(TechnicianUpdateInput input) onUpdate,
  }) {
    return TechnicianFormDialog._(
      technician: technician,
      onCreate: null,
      onUpdate: onUpdate,
    );
  }

  final Technician? technician;

  final Future<void> Function(
    TechnicianCreateInput input,
  )? onCreate;

  final Future<void> Function(
    TechnicianUpdateInput input,
  )? onUpdate;

  bool get isEditing => technician != null;

  @override
  State<TechnicianFormDialog> createState() =>
      _TechnicianFormDialogState();
}

class _TechnicianFormDialogState
    extends State<TechnicianFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _specializationController;
  late final TextEditingController _experienceController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final technician = widget.technician;

    _fullNameController = TextEditingController(
      text: technician?.fullName ?? '',
    );

    _mobileController = TextEditingController(
      text: technician?.mobile ?? '',
    );

    _specializationController = TextEditingController(
      text: technician?.specialization ?? '',
    );

    _experienceController = TextEditingController(
      text: technician?.experienceYears.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final experienceYears =
        int.tryParse(_experienceController.text.trim()) ?? 0;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEditing) {
        final onUpdate = widget.onUpdate;

        if (onUpdate == null) {
          throw StateError(
            'Technician update callback is missing.',
          );
        }

        await onUpdate(
          TechnicianUpdateInput(
            fullName: _fullNameController.text,
            mobile: _mobileController.text,
            specialization:
                _specializationController.text,
            experienceYears: experienceYears,
            includeSpecialization: true,
          ),
        );
      } else {
        final onCreate = widget.onCreate;

        if (onCreate == null) {
          throw StateError(
            'Technician creation callback is missing.',
          );
        }

        await onCreate(
          TechnicianCreateInput(
            fullName: _fullNameController.text,
            mobile: _mobileController.text,
            specialization:
                _specializationController.text,
            experienceYears: experienceYears,
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
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final technician = widget.technician;

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
            maxHeight: 820,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              autovalidateMode:
                  AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    context,
                    isEditing: isEditing,
                    technician: technician,
                  ),
                  const SizedBox(height: 26),
                  _buildInformationBanner(
                    isEditing: isEditing,
                    technician: technician,
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useTwoColumns =
                          constraints.maxWidth >= 560;

                      if (useTwoColumns) {
                        return Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFullNameField(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMobileField(),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _buildFullNameField(),
                          const SizedBox(height: 16),
                          _buildMobileField(),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSpecializationField(),
                  const SizedBox(height: 16),
                  _buildExperienceField(),
                  AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _errorMessage == null
                        ? const SizedBox.shrink(
                            key: ValueKey(
                              'no-technician-form-error',
                            ),
                          )
                        : Padding(
                            key: const ValueKey(
                              'technician-form-error',
                            ),
                            padding:
                                const EdgeInsets.only(
                                  top: 18,
                                ),
                            child: _FormErrorBox(
                              message: _errorMessage!,
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  _buildActions(isEditing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isEditing,
    required Technician? technician,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.88, end: 1),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              isEditing
                  ? Icons.manage_accounts_rounded
                  : Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? 'Edit Technician'
                    : 'Add Technician',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                isEditing
                    ? 'Update technician profile and '
                          'professional information.'
                    : 'Create a technician profile for '
                          'service assignments.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              if (technician != null) ...[
                const SizedBox(height: 7),
                Text(
                  technician.technicianCode,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildInformationBanner({
    required bool isEditing,
    required Technician? technician,
  }) {
    final hasLinkedUser = technician?.userId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing && hasLinkedUser
                  ? 'This technician is linked to a user '
                        'account. Editing this profile will '
                        'not remove that account link.'
                  : 'Technician codes are generated '
                        'automatically by the server. '
                        'Login-account linking can be managed '
                        'separately by an administrator.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      enabled: !_isSubmitting,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      maxLength: 100,
      decoration: const InputDecoration(
        labelText: 'Full name',
        hintText: 'Enter technician name',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (value) {
        final name = value?.trim() ?? '';

        if (name.isEmpty) {
          return 'Enter technician name.';
        }

        if (name.length < 3) {
          return 'Enter at least 3 characters.';
        }

        if (name.length > 100) {
          return 'Name cannot exceed 100 characters.';
        }

        final validName = RegExp(
          r"^[A-Za-zÀ-ÿ.'\- ]+$",
        ).hasMatch(name);

        if (!validName) {
          return 'Use letters and normal name characters.';
        }

        return null;
      },
    );
  }

  Widget _buildMobileField() {
    return TextFormField(
      controller: _mobileController,
      enabled: !_isSubmitting,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      maxLength: 15,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: const InputDecoration(
        labelText: 'Mobile number',
        hintText: '10 to 15 digits',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
      validator: (value) {
        final mobile = value?.trim() ?? '';

        if (mobile.isEmpty) {
          return 'Enter mobile number.';
        }

        if (!RegExp(r'^[0-9]{10,15}$').hasMatch(mobile)) {
          return 'Enter a valid 10 to 15 digit number.';
        }

        return null;
      },
    );
  }

  Widget _buildSpecializationField() {
    return TextFormField(
      controller: _specializationController,
      enabled: !_isSubmitting,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      maxLength: 150,
      decoration: const InputDecoration(
        labelText: 'Specialization',
        hintText:
            'Example: Electrical appliances, Mixer repair',
        prefixIcon: Icon(Icons.handyman_outlined),
        helperText:
            'Optional — describe the technician’s main skills.',
      ),
      validator: (value) {
        final specialization = value?.trim() ?? '';

        if (specialization.length > 150) {
          return 'Specialization cannot exceed '
              '150 characters.';
        }

        return null;
      },
    );
  }

  Widget _buildExperienceField() {
    return TextFormField(
      controller: _experienceController,
      enabled: !_isSubmitting,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 2,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onFieldSubmitted: (_) {
        _submit();
      },
      decoration: const InputDecoration(
        labelText: 'Experience',
        hintText: 'Years of experience',
        suffixText: 'years',
        prefixIcon: Icon(Icons.workspace_premium_outlined),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (text.isEmpty) {
          return 'Enter experience years.';
        }

        final experience = int.tryParse(text);

        if (experience == null) {
          return 'Enter a valid number.';
        }

        if (experience < 0 || experience > 60) {
          return 'Experience must be between 0 and 60.';
        }

        return null;
      },
    );
  }

  Widget _buildActions(bool isEditing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isSubmitting
                ? const SizedBox(
                    key: ValueKey('technician-saving'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isEditing
                        ? Icons.save_outlined
                        : Icons.person_add_alt_1_rounded,
                    key: const ValueKey(
                      'technician-save-icon',
                    ),
                  ),
          ),
          label: Text(
            _isSubmitting
                ? 'Saving...'
                : isEditing
                ? 'Save Changes'
                : 'Add Technician',
          ),
        ),
      ],
    );
  }
}

class _FormErrorBox extends StatelessWidget {
  const _FormErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('ApiException: ', '')
      .trim();
}
