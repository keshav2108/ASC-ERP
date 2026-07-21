import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'technician_model.dart';
import 'technician_service.dart';

final technicianServiceProvider = Provider<TechnicianService>(
  (ref) => TechnicianService(),
);

class TechnicianNotifier extends AsyncNotifier<List<Technician>> {
  late final TechnicianService _service;

  @override
  Future<List<Technician>> build() async {
    _service = ref.read(technicianServiceProvider);

    return _service.getTechnicians();
  }

  Future<void> refreshTechnicians({bool showLoading = true}) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(_service.getTechnicians);

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshTechniciansSilently() {
    return refreshTechnicians(showLoading: false);
  }

  Future<Technician> addTechnician(TechnicianCreateInput input) async {
    final createdTechnician = await _service.createTechnician(input);

    final existingTechnicians = state.value ?? <Technician>[];

    state = AsyncData([
      createdTechnician,
      ...existingTechnicians.where(
        (technician) => technician.id != createdTechnician.id,
      ),
    ]);

    return createdTechnician;
  }

  Future<Technician> editTechnician(
    int technicianId,
    TechnicianUpdateInput input,
  ) async {
    final updatedTechnician = await _service.updateTechnician(
      technicianId,
      input,
    );

    _replaceTechnician(updatedTechnician);

    return updatedTechnician;
  }

  Future<void> deactivateTechnician(int technicianId) async {
    await _service.deactivateTechnician(technicianId);

    final existingTechnicians = state.value ?? <Technician>[];

    state = AsyncData(
      existingTechnicians
          .where((technician) => technician.id != technicianId)
          .toList(),
    );
  }

  void _replaceTechnician(Technician updatedTechnician) {
    final existingTechnicians = state.value ?? <Technician>[];

    final technicianExists = existingTechnicians.any(
      (technician) => technician.id == updatedTechnician.id,
    );

    if (!technicianExists) {
      state = AsyncData([updatedTechnician, ...existingTechnicians]);

      return;
    }

    state = AsyncData(
      existingTechnicians.map((technician) {
        if (technician.id == updatedTechnician.id) {
          return updatedTechnician;
        }

        return technician;
      }).toList(),
    );
  }
}

final technicianProvider =
    AsyncNotifierProvider<TechnicianNotifier, List<Technician>>(
      TechnicianNotifier.new,
    );

final availableTechniciansProvider = Provider<AsyncValue<List<Technician>>>((
  ref,
) {
  final technicians = ref.watch(technicianProvider);

  return technicians.whenData((items) {
    final availableTechnicians = items
        .where((technician) => technician.isAvailable)
        .toList();

    availableTechnicians.sort(
      (first, second) => first.fullName.compareTo(second.fullName),
    );

    return availableTechnicians;
  });
});

final technicianByIdProvider = Provider.family<Technician?, int>((
  ref,
  technicianId,
) {
  final technicians = ref.watch(technicianProvider).value;

  if (technicians == null) {
    return null;
  }

  for (final technician in technicians) {
    if (technician.id == technicianId) {
      return technician;
    }
  }

  return null;
});
