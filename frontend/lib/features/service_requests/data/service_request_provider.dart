import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_request_model.dart';
import 'service_request_service.dart';

final serviceRequestServiceProvider = Provider<ServiceRequestService>(
  (ref) => ServiceRequestService(),
);

class ServiceRequestNotifier extends AsyncNotifier<List<ServiceRequest>> {
  late final ServiceRequestService _service;

  @override
  Future<List<ServiceRequest>> build() async {
    _service = ref.read(serviceRequestServiceProvider);

    return _service.getServiceRequests();
  }

  Future<void> refreshRequests() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(_service.getServiceRequests);
  }

  Future<ServiceRequest> addRequest(ServiceRequestCreateInput input) async {
    final createdRequest = await _service.createServiceRequest(input);

    final existingRequests = state.value ?? <ServiceRequest>[];

    state = AsyncData([createdRequest, ...existingRequests]);

    return createdRequest;
  }

  Future<ServiceRequest> editRequest(
    int serviceRequestId,
    ServiceRequestUpdateInput input,
  ) async {
    final updatedRequest = await _service.updateServiceRequest(
      serviceRequestId,
      input,
    );

    final existingRequests = state.value ?? <ServiceRequest>[];

    state = AsyncData(
      existingRequests.map((request) {
        if (request.id == serviceRequestId) {
          return updatedRequest;
        }

        return request;
      }).toList(),
    );

    return updatedRequest;
  }

  Future<void> cancelRequest(int serviceRequestId) async {
    await _service.cancelServiceRequest(serviceRequestId);

    final requests = await _service.getServiceRequests();

    state = AsyncData(requests);
  }
}

final serviceRequestProvider =
    AsyncNotifierProvider<ServiceRequestNotifier, List<ServiceRequest>>(
      ServiceRequestNotifier.new,
    );

final customerProductsProvider =
    FutureProvider.family<List<CustomerProduct>, int>((ref, customerId) {
      return ref
          .read(serviceRequestServiceProvider)
          .getCustomerProducts(customerId);
    });

final masterOptionsProvider = FutureProvider.family<List<MasterOption>, String>(
  (ref, optionType) {
    return ref.read(serviceRequestServiceProvider).getMasterOptions(optionType);
  },
);
