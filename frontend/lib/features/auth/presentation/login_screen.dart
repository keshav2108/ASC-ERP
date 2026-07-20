import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  ConsumerState<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(authProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final isDesktop =
              constraints.maxWidth >= 900;

          return Row(
            children: [
              if (isDesktop)
                const Expanded(
                  flex: 6,
                  child: _LoginBrandPanel(),
                ),
              Expanded(
                flex: isDesktop ? 4 : 1,
                child: Container(
                  color: AppColors.surface,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 430,
                        ),
                        child: _buildLoginForm(
                          context,
                          authState,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    AuthState authState,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _MobileLogo(),
          const SizedBox(height: 34),
          Text(
            'Welcome back',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in to manage your service centre.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            'Username',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            enabled: !authState.isLoading,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Enter username',
              prefixIcon: Icon(
                Icons.person_outline_rounded,
              ),
            ),
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Username is required';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Password',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            enabled: !authState.isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              _login();
            },
            decoration: InputDecoration(
              hintText: 'Enter password',
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword =
                        !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Password is required';
              }

              return null;
            },
          ),
          if (authState.errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.danger.withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: authState.isLoading
                  ? null
                  : _login,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Shree Sai Nath Enterprises',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLogo extends StatelessWidget {
  const _MobileLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.settings_suggest_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'ASC Manager',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF312E81),
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _GlowCircle(
              size: 260,
              opacity: 0.10,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _GlowCircle(
              size: 320,
              opacity: 0.08,
            ),
          ),
          const Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'ASC Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Spacer(),
              Text(
                'Run your service centre\nfrom one powerful platform.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 22),
              Text(
                'Manage complaints, technicians, job cards, '
                'inventory, invoices, payments and delivery '
                'with complete visibility.',
                style: TextStyle(
                  color: Color(0xFFE0E7FF),
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 36),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FeatureBadge(
                    icon: Icons.dashboard_rounded,
                    label: 'Live Dashboard',
                  ),
                  _FeatureBadge(
                    icon: Icons.engineering_rounded,
                    label: 'Job Workflow',
                  ),
                  _FeatureBadge(
                    icon: Icons.inventory_2_rounded,
                    label: 'Inventory',
                  ),
                  _FeatureBadge(
                    icon: Icons.payments_rounded,
                    label: 'Billing',
                  ),
                ],
              ),
              Spacer(),
              Text(
                'Authorized Service Centre Management System',
                style: TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(
          alpha: opacity,
        ),
      ),
    );
  }
}
