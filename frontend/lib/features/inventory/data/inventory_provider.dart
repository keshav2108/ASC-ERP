import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_model.dart';
import 'inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>(
  (ref) => InventoryService(),
);

final sparePartProvider =
    AsyncNotifierProvider<SparePartNotifier, List<SparePart>>(
      SparePartNotifier.new,
    );

final stockTransactionProvider =
    AsyncNotifierProvider<StockTransactionNotifier, List<StockTransaction>>(
      StockTransactionNotifier.new,
    );

class SparePartNotifier extends AsyncNotifier<List<SparePart>> {
  late final InventoryService _service;

  @override
  Future<List<SparePart>> build() async {
    _service = ref.read(inventoryServiceProvider);

    final parts = await _service.getSpareParts();

    return _sortSpareParts(parts);
  }

  Future<void> refreshSpareParts({
    bool includeInactive = false,
    bool showLoading = true,
  }) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(() async {
      final parts = await _service.getSpareParts(
        includeInactive: includeInactive,
      );

      return _sortSpareParts(parts);
    });

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshSparePartsSilently({bool includeInactive = false}) {
    return refreshSpareParts(
      includeInactive: includeInactive,
      showLoading: false,
    );
  }

  Future<SparePart> addSparePart(SparePartCreateInput input) async {
    final createdPart = await _service.createSparePart(input);

    final currentParts = state.asData?.value ?? const <SparePart>[];

    state = AsyncData(_sortSpareParts([...currentParts, createdPart]));

    return createdPart;
  }

  Future<SparePart> editSparePart(
    int sparePartId,
    SparePartUpdateInput input,
  ) async {
    final updatedPart = await _service.updateSparePart(sparePartId, input);

    applyServerSparePart(updatedPart);

    return updatedPart;
  }

  Future<void> deactivateSparePart(int sparePartId) async {
    await _service.deactivateSparePart(sparePartId);

    final currentParts = state.asData?.value ?? const <SparePart>[];

    state = AsyncData(
      currentParts
          .where((part) => part.id != sparePartId)
          .toList(growable: false),
    );
  }

  void applyServerSparePart(SparePart updatedPart) {
    final currentParts = state.asData?.value ?? const <SparePart>[];

    final partExists = currentParts.any((part) => part.id == updatedPart.id);

    final nextParts = partExists
        ? currentParts
              .map((part) {
                if (part.id == updatedPart.id) {
                  return updatedPart;
                }

                return part;
              })
              .toList(growable: false)
        : <SparePart>[...currentParts, updatedPart];

    state = AsyncData(_sortSpareParts(nextParts));
  }
}

class StockTransactionNotifier extends AsyncNotifier<List<StockTransaction>> {
  late final InventoryService _service;

  @override
  Future<List<StockTransaction>> build() async {
    _service = ref.read(inventoryServiceProvider);

    final transactions = await _service.getStockTransactions();

    return _sortTransactions(transactions);
  }

  Future<void> refreshTransactions({bool showLoading = true}) async {
    final previousState = state;

    if (showLoading) {
      state = const AsyncLoading();
    }

    final refreshedState = await AsyncValue.guard(() async {
      final transactions = await _service.getStockTransactions();

      return _sortTransactions(transactions);
    });

    if (!showLoading && refreshedState.hasError && previousState.hasValue) {
      return;
    }

    state = refreshedState;
  }

  Future<void> refreshTransactionsSilently() {
    return refreshTransactions(showLoading: false);
  }

  Future<StockTransaction> stockIn(StockInInput input) async {
    final transaction = await _service.stockIn(input);

    _recordTransaction(transaction);

    ref.invalidate(partTransactionsProvider(input.sparePartId));

    return transaction;
  }

  Future<StockTransaction> issueStock(StockIssueInput input) async {
    final transaction = await _service.issueStock(input);

    _recordTransaction(transaction);

    ref.invalidate(partTransactionsProvider(input.sparePartId));

    ref.invalidate(jobCardTransactionsProvider(input.jobCardId));

    return transaction;
  }

  Future<StockTransaction> issueStockToJobCard(StockIssueInput input) async {
    final transaction = await _service.issueStockToJobCard(input);

    _recordTransaction(transaction);

    ref.invalidate(partTransactionsProvider(input.sparePartId));

    ref.invalidate(jobCardTransactionsProvider(input.jobCardId));

    return transaction;
  }

  Future<StockTransaction> returnStock(StockReturnInput input) async {
    final transaction = await _service.returnStock(input);

    _recordTransaction(transaction);

    ref.invalidate(partTransactionsProvider(input.sparePartId));

    ref.invalidate(jobCardTransactionsProvider(input.jobCardId));

    return transaction;
  }

  Future<StockTransaction> adjustStock(StockAdjustmentInput input) async {
    final transaction = await _service.adjustStock(input);

    _recordTransaction(transaction);

    ref.invalidate(partTransactionsProvider(input.sparePartId));

    return transaction;
  }

  void _recordTransaction(StockTransaction transaction) {
    final currentTransactions =
        state.asData?.value ?? const <StockTransaction>[];

    final nextTransactions = [
      transaction,
      ...currentTransactions.where((item) => item.id != transaction.id),
    ];

    state = AsyncData(_sortTransactions(nextTransactions));

    ref
        .read(sparePartProvider.notifier)
        .applyServerSparePart(transaction.sparePart);
  }
}

final lowStockPartsProvider = Provider<AsyncValue<List<SparePart>>>((ref) {
  return ref.watch(sparePartProvider).whenData((parts) {
    final lowStockParts = parts
        .where((part) => part.isActive && part.isLowStock)
        .toList(growable: false);

    return _sortSpareParts(lowStockParts);
  });
});

final outOfStockPartsProvider = Provider<AsyncValue<List<SparePart>>>((ref) {
  return ref.watch(sparePartProvider).whenData((parts) {
    return parts
        .where((part) => part.isActive && part.isOutOfStock)
        .toList(growable: false);
  });
});

final sparePartByIdProvider = Provider.family<SparePart?, int>((
  ref,
  sparePartId,
) {
  final parts = ref.watch(sparePartProvider).asData?.value;

  if (parts == null) {
    return null;
  }

  for (final part in parts) {
    if (part.id == sparePartId) {
      return part;
    }
  }

  return null;
});

final partTransactionsProvider =
    FutureProvider.family<List<StockTransaction>, int>((ref, sparePartId) {
      return ref
          .read(inventoryServiceProvider)
          .getPartTransactions(sparePartId);
    });

final jobCardTransactionsProvider =
    FutureProvider.family<List<StockTransaction>, int>((ref, jobCardId) {
      return ref
          .read(inventoryServiceProvider)
          .getJobCardTransactions(jobCardId);
    });

List<SparePart> _sortSpareParts(Iterable<SparePart> parts) {
  final sortedParts = parts.toList();

  sortedParts.sort((first, second) {
    final firstActiveOrder = first.isActive ? 0 : 1;
    final secondActiveOrder = second.isActive ? 0 : 1;

    final activeComparison = firstActiveOrder.compareTo(secondActiveOrder);

    if (activeComparison != 0) {
      return activeComparison;
    }

    final nameComparison = first.partName.toLowerCase().compareTo(
      second.partName.toLowerCase(),
    );

    if (nameComparison != 0) {
      return nameComparison;
    }

    return first.partCode.compareTo(second.partCode);
  });

  return List<SparePart>.unmodifiable(sortedParts);
}

List<StockTransaction> _sortTransactions(
  Iterable<StockTransaction> transactions,
) {
  final sortedTransactions = transactions.toList();

  sortedTransactions.sort((first, second) {
    final dateComparison = second.createdAt.compareTo(first.createdAt);

    if (dateComparison != 0) {
      return dateComparison;
    }

    return second.id.compareTo(first.id);
  });

  return List<StockTransaction>.unmodifiable(sortedTransactions);
}
