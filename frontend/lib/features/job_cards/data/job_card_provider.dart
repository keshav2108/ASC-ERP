import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_provider.dart';
import '../../service_requests/data/service_request_provider.dart';
import '../../technicians/data/technician_provider.dart';
import 'job_card_model.dart';
import 'job_card_service.dart';

final jobCardServiceProvider = Provider<JobCardService>(
  (ref) => JobCardService(),
);

class JobCardNotifier extends AsyncNotifier<List<JobCard>> {
  late final JobCardService _service;

  @override
  Future<List<JobCard>> build() async {
    _service = ref.read(jobCardServiceProvider);

    return _service.getJobCards();
  }

  Future<void> refreshJobCards({bool showLoading = true}) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(_service.getJobCards);

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshJobCardsSilently() {
    return refreshJobCards(showLoading: false);
  }

  Future<JobCard> refreshJobCard(int jobCardId) async {
    final refreshedJobCard = await _service.getJobCard(jobCardId);

    _replaceJobCard(refreshedJobCard);
    _refreshRelatedProviders();

    return refreshedJobCard;
  }

  Future<JobCard> assignTechnician(
    int serviceRequestId,
    TechnicianAssignmentInput input,
  ) async {
    final createdJobCard = await _service.assignTechnician(
      serviceRequestId,
      input,
    );

    final existingJobCards = state.value ?? <JobCard>[];

    state = AsyncData([
      createdJobCard,
      ...existingJobCards.where((jobCard) => jobCard.id != createdJobCard.id),
    ]);

    _refreshRelatedProviders();

    return createdJobCard;
  }

  Future<JobCard> editJobCard(int jobCardId, JobCardUpdateInput input) async {
    final updatedJobCard = await _service.updateJobCard(jobCardId, input);

    _replaceJobCard(updatedJobCard);

    _refreshRelatedProviders();

    return updatedJobCard;
  }

  Future<JobCard> changeStatus(int jobCardId, String targetStatus) async {
    final updatedJobCard = await _service.changeJobStatus(
      jobCardId,
      targetStatus,
    );

    _replaceJobCard(updatedJobCard);

    _refreshRelatedProviders();

    return updatedJobCard;
  }

  Future<JobCard> deliverJobCard(
    int jobCardId,
    JobCardDeliveryInput input,
  ) async {
    final deliveredJobCard = await _service.deliverJobCard(jobCardId, input);

    _replaceJobCard(deliveredJobCard);

    _refreshRelatedProviders();

    return deliveredJobCard;
  }

  Future<JobCard> reopenDeliveredJobCard(int jobCardId) async {
    final reopenedJobCard = await _service.reopenDeliveredJobCard(jobCardId);

    _replaceJobCard(reopenedJobCard);

    _refreshRelatedProviders();

    return reopenedJobCard;
  }

  void _refreshRelatedProviders() {
    unawaited(
      ref.read(serviceRequestProvider.notifier).refreshRequestsSilently(),
    );

    unawaited(ref.read(dashboardProvider.notifier).refreshDashboardSilently());
    unawaited(
      ref.read(technicianProvider.notifier).refreshTechniciansSilently(),
    );
  }

  void _replaceJobCard(JobCard updatedJobCard) {
    final existingJobCards = state.value ?? <JobCard>[];

    final jobCardExists = existingJobCards.any(
      (jobCard) => jobCard.id == updatedJobCard.id,
    );

    if (!jobCardExists) {
      state = AsyncData([updatedJobCard, ...existingJobCards]);

      return;
    }

    state = AsyncData(
      existingJobCards.map((jobCard) {
        if (jobCard.id == updatedJobCard.id) {
          return updatedJobCard;
        }

        return jobCard;
      }).toList(),
    );
  }
}

final jobCardProvider = AsyncNotifierProvider<JobCardNotifier, List<JobCard>>(
  JobCardNotifier.new,
);

final technicianJobCardsProvider = FutureProvider.family<List<JobCard>, int>((
  ref,
  technicianId,
) {
  return ref.read(jobCardServiceProvider).getTechnicianJobCards(technicianId);
});

final allowedJobTransitionsProvider =
    FutureProvider.family<List<WorkflowTransition>, String>((
      ref,
      currentStatus,
    ) {
      return ref
          .read(jobCardServiceProvider)
          .getAllowedTransitions(currentStatus);
    });
