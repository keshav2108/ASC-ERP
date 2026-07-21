import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'invoice_model.dart';
import 'invoice_service.dart';

final invoiceServiceProvider = Provider<InvoiceService>(
  (ref) => InvoiceService(),
);

class InvoiceNotifier extends AsyncNotifier<List<Invoice>> {
  late final InvoiceService _service;

  @override
  Future<List<Invoice>> build() async {
    _service = ref.read(invoiceServiceProvider);

    return _service.getInvoices();
  }

  Future<void> refreshInvoices({bool showLoading = true}) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(_service.getInvoices);

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshInvoicesSilently() {
    return refreshInvoices(showLoading: false);
  }

  Future<Invoice> generateInvoice(InvoiceCreateInput input) async {
    final createdInvoice = await _service.createInvoice(input);

    final existingInvoices = state.value ?? <Invoice>[];

    state = AsyncData([
      createdInvoice,
      ...existingInvoices.where((invoice) => invoice.id != createdInvoice.id),
    ]);

    unawaited(ref.read(dashboardProvider.notifier).refreshDashboardSilently());

    return createdInvoice;
  }

  Future<Invoice> cancelInvoice(int invoiceId) async {
    final cancelledInvoice = await _service.cancelInvoice(invoiceId);

    _replaceInvoice(cancelledInvoice);

    unawaited(ref.read(dashboardProvider.notifier).refreshDashboardSilently());

    return cancelledInvoice;
  }

  void _replaceInvoice(Invoice updatedInvoice) {
    final existingInvoices = state.value ?? <Invoice>[];

    state = AsyncData(
      existingInvoices
          .map((invoice) {
            if (invoice.id == updatedInvoice.id) {
              return updatedInvoice;
            }

            return invoice;
          })
          .toList(growable: false),
    );
  }
}

final invoiceProvider = AsyncNotifierProvider<InvoiceNotifier, List<Invoice>>(
  InvoiceNotifier.new,
);

final invoiceByIdProvider = FutureProvider.family<Invoice, int>((
  ref,
  invoiceId,
) {
  return ref.read(invoiceServiceProvider).getInvoice(invoiceId);
});

final invoiceByJobCardProvider = FutureProvider.family<Invoice, int>((
  ref,
  jobCardId,
) {
  return ref.read(invoiceServiceProvider).getInvoiceByJobCard(jobCardId);
});
