import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_provider.dart';
import '../../invoices/data/invoice_provider.dart';
import 'payment_model.dart';
import 'payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(),
);

class PaymentNotifier extends AsyncNotifier<List<Payment>> {
  late final PaymentService _service;

  @override
  Future<List<Payment>> build() async {
    _service = ref.read(paymentServiceProvider);

    return _service.getPayments();
  }

  Future<void> refreshPayments({bool showLoading = true}) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(_service.getPayments);

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshPaymentsSilently() {
    return refreshPayments(showLoading: false);
  }

  Future<Payment> recordPayment(PaymentCreateInput input) async {
    final createdPayment = await _service.createPayment(input);

    final existingPayments = state.value ?? const <Payment>[];

    state = AsyncData(<Payment>[
      createdPayment,
      ...existingPayments.where((payment) => payment.id != createdPayment.id),
    ]);

    _refreshRelatedProviders(createdPayment.invoiceId);

    return createdPayment;
  }

  Future<Payment> cancelPayment(int paymentId) async {
    final cancelledPayment = await _service.cancelPayment(paymentId);

    final existingPayments = state.value ?? const <Payment>[];

    state = AsyncData(
      existingPayments.map((payment) {
        if (payment.id == paymentId) {
          return cancelledPayment;
        }

        return payment;
      }).toList(),
    );

    _refreshRelatedProviders(cancelledPayment.invoiceId);

    return cancelledPayment;
  }

  void _refreshRelatedProviders(int invoiceId) {
    ref.invalidate(invoicePaymentSummaryProvider(invoiceId));

    unawaited(ref.read(invoiceProvider.notifier).refreshInvoicesSilently());
    unawaited(ref.read(dashboardProvider.notifier).refreshDashboardSilently());
  }
}

final paymentProvider = AsyncNotifierProvider<PaymentNotifier, List<Payment>>(
  PaymentNotifier.new,
);

final invoicePaymentSummaryProvider = FutureProvider.autoDispose
    .family<InvoicePaymentSummary, int>((ref, invoiceId) {
      return ref.read(paymentServiceProvider).getInvoicePayments(invoiceId);
    });

final paymentDetailsProvider = FutureProvider.autoDispose.family<Payment, int>((
  ref,
  paymentId,
) {
  return ref.read(paymentServiceProvider).getPayment(paymentId);
});
