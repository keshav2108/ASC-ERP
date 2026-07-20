import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_model.dart';
import 'customer_service.dart';

final customerServiceProvider = Provider<CustomerService>(
  (ref) => CustomerService(),
);

class CustomerNotifier extends AsyncNotifier<List<Customer>> {
  late final CustomerService _service;

  @override
  Future<List<Customer>> build() async {
    _service = ref.read(customerServiceProvider);

    return _service.getCustomers();
  }

  Future<void> refreshCustomers() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(_service.getCustomers);
  }

  Future<Customer> addCustomer(CustomerInput input) async {
    final customer = await _service.createCustomer(input);

    final existingCustomers = state.value ?? <Customer>[];

    state = AsyncData([customer, ...existingCustomers]);

    return customer;
  }

  Future<Customer> editCustomer(int customerId, CustomerInput input) async {
    final updatedCustomer = await _service.updateCustomer(customerId, input);

    final existingCustomers = state.value ?? <Customer>[];

    state = AsyncData(
      existingCustomers.map((customer) {
        if (customer.id == customerId) {
          return updatedCustomer;
        }

        return customer;
      }).toList(),
    );

    return updatedCustomer;
  }

  Future<void> deactivateCustomer(int customerId) async {
    await _service.deactivateCustomer(customerId);

    final existingCustomers = state.value ?? <Customer>[];

    state = AsyncData(
      existingCustomers.where((customer) => customer.id != customerId).toList(),
    );
  }
}

final customerProvider =
    AsyncNotifierProvider<CustomerNotifier, List<Customer>>(
      CustomerNotifier.new,
    );
