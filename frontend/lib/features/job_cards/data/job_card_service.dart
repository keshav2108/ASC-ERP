import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'job_card_model.dart';

class JobCardService {
  Future<List<JobCard>> getJobCards() async {
    try {
      final response = await ApiClient.dio.get('/api/v1/job-cards/');

      return _parseJobCards(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<JobCard>> getTechnicianJobCards(int technicianId) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/job-cards/technician/$technicianId',
      );

      return _parseJobCards(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JobCard> getJobCard(int jobCardId) async {
    try {
      final response = await ApiClient.dio.get('/api/v1/job-cards/$jobCardId');

      return JobCard.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JobCard> updateJobCard(int jobCardId, JobCardUpdateInput input) async {
    try {
      final response = await ApiClient.dio.patch(
        '/api/v1/job-cards/$jobCardId',
        data: input.toJson(),
      );

      return JobCard.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JobCard> assignTechnician(
    int serviceRequestId,
    TechnicianAssignmentInput input,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/v1/service-requests/'
        '$serviceRequestId/assign-technician',
        data: input.toJson(),
      );

      return JobCard.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JobCard> changeJobStatus(int jobCardId, String targetStatus) async {
    final endpoint = _workflowEndpoint(jobCardId, targetStatus);

    try {
      final response = await ApiClient.dio.post(endpoint);

      return JobCard.fromJson(_asResponseMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JobCard> deliverJobCard(
    int jobCardId,
    JobCardDeliveryInput input,
  ) async {
    final deliveryRemarks = input.deliveryRemarks?.trim();

    try {
      await ApiClient.dio.post(
        '/api/v1/deliveries/job-card/$jobCardId',
        data: {
          'delivered_to': input.deliveredTo.trim(),
          'remarks': deliveryRemarks == null || deliveryRemarks.isEmpty
              ? null
              : deliveryRemarks,
        },
      );

      return getJobCard(jobCardId);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<WorkflowTransition>> getAllowedTransitions(
    String currentStatus,
  ) async {
    try {
      final response = await ApiClient.dio.get(
        '/api/v1/workflow-transitions/'
        'allowed/$currentStatus',
      );

      if (response.data is! List) {
        throw const ApiException(
          message: 'The server returned invalid workflow transitions.',
        );
      }

      return (response.data as List)
          .map(
            (item) => WorkflowTransition.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((transition) => transition.isActive)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

String _workflowEndpoint(int jobCardId, String targetStatus) {
  final normalizedStatus = targetStatus.trim().toUpperCase().replaceAll(
    ' ',
    '_',
  );

  switch (normalizedStatus) {
    case 'ACCEPTED':
      return '/api/v1/job-cards/'
          '$jobCardId/accept';

    case 'DIAGNOSIS':
      return '/api/v1/job-cards/'
          '$jobCardId/start-diagnosis';

    case 'WAITING_PARTS':
      return '/api/v1/job-cards/'
          '$jobCardId/waiting-for-parts';

    case 'REPAIR_IN_PROGRESS':
      return '/api/v1/job-cards/'
          '$jobCardId/start-repair';

    case 'TESTING':
      return '/api/v1/job-cards/'
          '$jobCardId/start-testing';

    case 'COMPLETED':
      return '/api/v1/job-cards/'
          '$jobCardId/complete';

    case 'READY_FOR_DELIVERY':
      return '/api/v1/job-cards/'
          '$jobCardId/ready-for-delivery';

    case 'CANCELLED':
      return '/api/v1/job-cards/'
          '$jobCardId/cancel';

    case 'DELIVERED':
      throw const ApiException(
        message: 'Use the delivery form to deliver the product.',
      );

    default:
      throw ApiException(message: 'Unsupported job status: $targetStatus');
  }
}

List<JobCard> _parseJobCards(dynamic responseData) {
  if (responseData is! List) {
    throw const ApiException(
      message: 'The server returned an invalid job-card list.',
    );
  }

  return responseData
      .map((item) => JobCard.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

Map<String, dynamic> _asResponseMap(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    return responseData;
  }

  if (responseData is Map) {
    return Map<String, dynamic>.from(responseData);
  }

  throw const ApiException(
    message: 'The server returned an invalid job-card response.',
  );
}
