import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_model.dart';
import 'dashboard_service.dart';

final dashboardServiceProvider = Provider<DashboardService>(
  (ref) => DashboardService(),
);

class DashboardNotifier extends AsyncNotifier<DashboardOverview> {
  late final DashboardService _dashboardService;

  @override
  Future<DashboardOverview> build() async {
    _dashboardService = ref.read(dashboardServiceProvider);

    return _dashboardService.getOverview();
  }

  Future<void> refreshDashboard({bool showLoading = true}) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(
      _dashboardService.getOverview,
    );

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshDashboardSilently() {
    return refreshDashboard(showLoading: false);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardOverview>(
      DashboardNotifier.new,
    );
