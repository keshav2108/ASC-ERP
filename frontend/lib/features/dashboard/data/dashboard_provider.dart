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

  Future<void> refreshDashboard() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(_dashboardService.getOverview);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardOverview>(
      DashboardNotifier.new,
    );
