import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthState {
  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.errorMessage,
    this.user,
  });

  const AuthState.initial()
    : isLoading = true,
      isAuthenticated = false,
      errorMessage = null,
      user = null;

  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;
  final Map<String, dynamic>? user;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? user,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      user: clearUser ? null : user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);

    ApiClient.configure(onUnauthorized: _handleUnauthorized);

    Future.microtask(restoreSession);

    return const AuthState.initial();
  }

  Future<void> _handleUnauthorized() async {
    await _authService.logout();

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      clearError: true,
      clearUser: true,
    );
  }

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final isAuthenticated = await _authService.restoreSession();

      if (!isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          clearError: true,
          clearUser: true,
        );

        return;
      }

      final user = await _authService.getCurrentUser();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        clearError: true,
      );
    } catch (_) {
      await _authService.logout();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearError: true,
        clearUser: true,
      );
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.login(username: username, password: password);

      final user = await _authService.getCurrentUser();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        clearError: true,
      );

      return true;
    } catch (error) {
      await _authService.logout();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
        clearUser: true,
      );

      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);

    await _authService.logout();

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      clearError: true,
      clearUser: true,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
