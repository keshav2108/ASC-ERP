import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../dashboard/data/dashboard_provider.dart';
import '../../job_cards/data/job_card_model.dart';
import '../../job_cards/data/job_card_provider.dart';
import '../data/inventory_model.dart';
import '../data/inventory_provider.dart';
import 'spare_part_form_dialog.dart';
import 'stock_transaction_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _partSearchController = TextEditingController();

  final _transactionSearchController = TextEditingController();

  String _partSearchQuery = '';
  String _selectedBrand = 'ALL';
  String _selectedCategory = 'ALL';
  String _selectedStockStatus = 'ALL';

  String _transactionSearchQuery = '';
  String _selectedTransactionType = 'ALL';

  bool get _canManageInventory {
    final role = AppRoles.fromUser(ref.read(authProvider).user);

    return AppPermissions.canManageInventory(role);
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _partSearchController.dispose();
    _transactionSearchController.dispose();

    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(sparePartProvider.notifier).refreshSpareParts(),
      ref.read(stockTransactionProvider.notifier).refreshTransactions(),
      ref.read(jobCardProvider.notifier).refreshJobCards(),
    ]);
  }

  bool _checkManagementPermission() {
    if (_canManageInventory) {
      return true;
    }

    _showMessage(
      'Only Admin or Service Manager can manage inventory.',
      isError: true,
    );

    return false;
  }

  Future<void> _addSparePart() async {
    if (!_checkManagementPermission()) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return SparePartFormDialog.create(
          onCreate: (input) async {
            await ref.read(sparePartProvider.notifier).addSparePart(input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('Spare part added successfully.');
  }

  Future<void> _editSparePart(SparePart sparePart) async {
    if (!_checkManagementPermission()) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return SparePartFormDialog.edit(
          sparePart: sparePart,
          onUpdate: (input) async {
            await ref
                .read(sparePartProvider.notifier)
                .editSparePart(sparePart.id, input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('${sparePart.partCode} updated successfully.');
  }

  Future<void> _deactivateSparePart(SparePart sparePart) async {
    if (!_checkManagementPermission()) {
      return;
    }

    if (!sparePart.isActive) {
      _showMessage('This spare part is already inactive.', isError: true);

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.inventory_2_outlined, color: AppColors.danger),
          title: const Text('Deactivate spare part?'),
          content: Text(
            '${sparePart.partName} '
            '(${sparePart.partCode}) will no longer '
            'be available for stock transactions.\n\n'
            'Existing transaction history will remain saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Keep Active'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.block_rounded),
              label: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(sparePartProvider.notifier)
          .deactivateSparePart(sparePart.id);

      ref.invalidate(dashboardProvider);

      if (mounted) {
        _showMessage('${sparePart.partCode} deactivated successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error), isError: true);
      }
    }
  }

  Future<void> _stockIn(SparePart sparePart) async {
    if (!_checkManagementPermission()) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StockTransactionDialog.stockIn(
          sparePart: sparePart,
          onSubmit: (input) async {
            await ref.read(stockTransactionProvider.notifier).stockIn(input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('Stock added to ${sparePart.partCode}.');
  }

  Future<List<JobCard>?> _loadJobCardsForTransaction() async {
    var jobCards = ref.read(jobCardProvider).asData?.value;

    if (jobCards == null) {
      try {
        await ref.read(jobCardProvider.notifier).refreshJobCards();

        jobCards = ref.read(jobCardProvider).asData?.value;
      } catch (error) {
        if (mounted) {
          _showMessage(_cleanError(error), isError: true);
        }

        return null;
      }
    }

    if (jobCards == null || jobCards.isEmpty) {
      _showMessage('No Job Cards are currently available.', isError: true);

      return null;
    }

    return jobCards;
  }

  Future<void> _issueStock(SparePart sparePart) async {
    if (!_checkManagementPermission()) {
      return;
    }

    if (sparePart.currentStock <= 0) {
      _showMessage('${sparePart.partName} is out of stock.', isError: true);

      return;
    }

    final jobCards = await _loadJobCardsForTransaction();

    if (jobCards == null || !mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StockTransactionDialog.issue(
          sparePart: sparePart,
          jobCards: jobCards,
          onSubmit: (input) async {
            await ref.read(stockTransactionProvider.notifier).issueStock(input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('${sparePart.partCode} issued successfully.');
  }

  Future<void> _returnStock(SparePart sparePart) async {
    if (!_checkManagementPermission()) {
      return;
    }

    final jobCards = await _loadJobCardsForTransaction();

    if (jobCards == null || !mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StockTransactionDialog.stockReturn(
          sparePart: sparePart,
          jobCards: jobCards,
          onSubmit: (input) async {
            await ref
                .read(stockTransactionProvider.notifier)
                .returnStock(input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('${sparePart.partCode} returned successfully.');
  }

  Future<void> _adjustStock(SparePart sparePart) async {
    if (!_checkManagementPermission()) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StockTransactionDialog.adjustment(
          sparePart: sparePart,
          onSubmit: (input) async {
            await ref
                .read(stockTransactionProvider.notifier)
                .adjustStock(input);
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    ref.invalidate(dashboardProvider);

    _showMessage('${sparePart.partCode} stock adjusted successfully.');
  }

  void _showSparePartDetails(SparePart sparePart) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _SparePartDetailsDialog(
          sparePart: sparePart,
          canManage: _canManageInventory,
          onEdit: () {
            Navigator.of(context).pop();
            _editSparePart(sparePart);
          },
          onStockIn: () {
            Navigator.of(context).pop();
            _stockIn(sparePart);
          },
          onIssue: () {
            Navigator.of(context).pop();
            _issueStock(sparePart);
          },
          onReturn: () {
            Navigator.of(context).pop();
            _returnStock(sparePart);
          },
          onAdjust: () {
            Navigator.of(context).pop();
            _adjustStock(sparePart);
          },
        );
      },
    );
  }

  void _clearPartFilters() {
    _partSearchController.clear();

    setState(() {
      _partSearchQuery = '';
      _selectedBrand = 'ALL';
      _selectedCategory = 'ALL';
      _selectedStockStatus = 'ALL';
    });
  }

  void _clearTransactionFilters() {
    _transactionSearchController.clear();

    setState(() {
      _transactionSearchQuery = '';
      _selectedTransactionType = 'ALL';
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final role = AppRoles.fromUser(authState.user);

    final canManage = AppPermissions.canManageInventory(role);

    final partsState = ref.watch(sparePartProvider);

    final transactionsState = ref.watch(stockTransactionProvider);

    final parts = partsState.asData?.value ?? const <SparePart>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 700 ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InventoryHeader(
                canManage: canManage,
                onAdd: _addSparePart,
                onRefresh: _refreshAll,
              ),
              const SizedBox(height: 18),
              _InventorySummary(parts: parts),
              if (!canManage) ...[
                const SizedBox(height: 14),
                const _ReadOnlyNotice(),
              ],
              const SizedBox(height: 18),
              _InventoryTabBar(controller: _tabController),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSparePartsTab(partsState, canManage),
                    _buildTransactionsTab(transactionsState),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSparePartsTab(
    AsyncValue<List<SparePart>> partsState,
    bool canManage,
  ) {
    return partsState.when(
      data: (parts) {
        final brands = <String>{
          'ALL',
          ...parts
              .map((part) => part.displayBrand)
              .where((brand) => brand.trim().isNotEmpty),
        }.toList()..sort(_sortFilterValues);

        final categories = <String>{
          'ALL',
          ...parts
              .map((part) => part.displayCategory)
              .where((category) => category.trim().isNotEmpty),
        }.toList()..sort(_sortFilterValues);

        final filteredParts = parts
            .where((part) {
              final search = _partSearchQuery.trim().toLowerCase();

              final matchesSearch =
                  search.isEmpty ||
                  part.partCode.toLowerCase().contains(search) ||
                  part.partName.toLowerCase().contains(search) ||
                  part.displayBrand.toLowerCase().contains(search) ||
                  part.displayCategory.toLowerCase().contains(search);

              final matchesBrand =
                  _selectedBrand == 'ALL' ||
                  part.displayBrand == _selectedBrand;

              final matchesCategory =
                  _selectedCategory == 'ALL' ||
                  part.displayCategory == _selectedCategory;

              final matchesStock = _matchesStockFilter(
                part,
                _selectedStockStatus,
              );

              return matchesSearch &&
                  matchesBrand &&
                  matchesCategory &&
                  matchesStock;
            })
            .toList(growable: false);

        return LayoutBuilder(
          builder: (context, constraints) {
            final useTable = constraints.maxWidth >= 900;

            return Column(
              children: [
                _PartFilters(
                  searchController: _partSearchController,
                  selectedBrand: brands.contains(_selectedBrand)
                      ? _selectedBrand
                      : 'ALL',
                  selectedCategory: categories.contains(_selectedCategory)
                      ? _selectedCategory
                      : 'ALL',
                  selectedStockStatus: _selectedStockStatus,
                  brands: brands,
                  categories: categories,
                  onSearchChanged: (value) {
                    setState(() {
                      _partSearchQuery = value;
                    });
                  },
                  onBrandChanged: (value) {
                    setState(() {
                      _selectedBrand = value ?? 'ALL';
                    });
                  },
                  onCategoryChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'ALL';
                    });
                  },
                  onStockStatusChanged: (value) {
                    setState(() {
                      _selectedStockStatus = value ?? 'ALL';
                    });
                  },
                  onClear: _clearPartFilters,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: filteredParts.isEmpty
                      ? _EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No spare parts found',
                          message: parts.isEmpty
                              ? 'Add the first spare part to begin inventory management.'
                              : 'Change or clear the current filters.',
                          actionLabel: canManage && parts.isEmpty
                              ? 'Add Spare Part'
                              : null,
                          onAction: canManage && parts.isEmpty
                              ? _addSparePart
                              : null,
                        )
                      : useTable
                      ? _SparePartsTable(
                          parts: filteredParts,
                          availableWidth: constraints.maxWidth,
                          canManage: canManage,
                          onRefresh: _refreshAll,
                          onView: _showSparePartDetails,
                          onEdit: _editSparePart,
                          onStockIn: _stockIn,
                          onIssue: _issueStock,
                          onReturn: _returnStock,
                          onAdjust: _adjustStock,
                          onDeactivate: _deactivateSparePart,
                        )
                      : _SparePartsCardList(
                          parts: filteredParts,
                          canManage: canManage,
                          onRefresh: _refreshAll,
                          onView: _showSparePartDetails,
                          onEdit: _editSparePart,
                          onStockIn: _stockIn,
                          onIssue: _issueStock,
                          onReturn: _returnStock,
                          onAdjust: _adjustStock,
                          onDeactivate: _deactivateSparePart,
                        ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const _LoadingState(message: 'Loading spare parts...'),
      error: (error, stackTrace) {
        return _ErrorState(
          message: _cleanError(error),
          onRetry: () {
            ref.read(sparePartProvider.notifier).refreshSpareParts();
          },
        );
      },
    );
  }

  Widget _buildTransactionsTab(
    AsyncValue<List<StockTransaction>> transactionsState,
  ) {
    return transactionsState.when(
      data: (transactions) {
        final filteredTransactions = transactions
            .where((transaction) {
              final search = _transactionSearchQuery.trim().toLowerCase();

              final matchesSearch =
                  search.isEmpty ||
                  transaction.sparePart.partCode.toLowerCase().contains(
                    search,
                  ) ||
                  transaction.sparePart.partName.toLowerCase().contains(
                    search,
                  ) ||
                  transaction.displayReference.toLowerCase().contains(search) ||
                  transaction.displayRemarks.toLowerCase().contains(search);

              final matchesType =
                  _selectedTransactionType == 'ALL' ||
                  transaction.transactionType == _selectedTransactionType;

              return matchesSearch && matchesType;
            })
            .toList(growable: false);

        return LayoutBuilder(
          builder: (context, constraints) {
            final useTable = constraints.maxWidth >= 850;

            return Column(
              children: [
                _TransactionFilters(
                  searchController: _transactionSearchController,
                  selectedType: _selectedTransactionType,
                  onSearchChanged: (value) {
                    setState(() {
                      _transactionSearchQuery = value;
                    });
                  },
                  onTypeChanged: (value) {
                    setState(() {
                      _selectedTransactionType = value ?? 'ALL';
                    });
                  },
                  onClear: _clearTransactionFilters,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: filteredTransactions.isEmpty
                      ? _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions found',
                          message: transactions.isEmpty
                              ? 'Inventory transactions will appear here after stock activity.'
                              : 'Change or clear the current filters.',
                        )
                      : useTable
                      ? _TransactionsTable(
                          transactions: filteredTransactions,
                          availableWidth: constraints.maxWidth,
                          onRefresh: _refreshAll,
                        )
                      : _TransactionsCardList(
                          transactions: filteredTransactions,
                          onRefresh: _refreshAll,
                        ),
                ),
              ],
            );
          },
        );
      },
      loading: () =>
          const _LoadingState(message: 'Loading inventory transactions...'),
      error: (error, stackTrace) {
        return _ErrorState(
          message: _cleanError(error),
          onRetry: () {
            ref.read(stockTransactionProvider.notifier).refreshTransactions();
          },
        );
      },
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({
    required this.canManage,
    required this.onAdd,
    required this.onRefresh,
  });

  final bool canManage;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Manage spare parts, stock levels and transaction history.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            if (canManage)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Spare Part'),
              ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({required this.parts});

  final List<SparePart> parts;

  @override
  Widget build(BuildContext context) {
    final activeParts = parts
        .where((part) => part.isActive)
        .toList(growable: false);

    final lowStockCount = activeParts
        .where((part) => part.isLowStock && !part.isOutOfStock)
        .length;

    final outOfStockCount = activeParts
        .where((part) => part.isOutOfStock)
        .length;

    final purchaseValue = activeParts.fold<double>(
      0,
      (total, part) => total + part.currentPurchaseValue,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1050
            ? (constraints.maxWidth - 42) / 4
            : constraints.maxWidth >= 600
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _SummaryCard(
              width: cardWidth,
              label: 'Active Parts',
              value: '${activeParts.length}',
              icon: Icons.precision_manufacturing_rounded,
              accent: AppColors.primary,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Low Stock',
              value: '$lowStockCount',
              icon: Icons.warning_amber_rounded,
              accent: AppColors.warning,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Out of Stock',
              value: '$outOfStockCount',
              icon: Icons.remove_shopping_cart_outlined,
              accent: AppColors.danger,
            ),
            _SummaryCard(
              width: cardWidth,
              label: 'Purchase Value',
              value: _formatCurrency(purchaseValue),
              icon: Icons.currency_rupee_rounded,
              accent: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Opacity(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - animation)),
            child: child,
          ),
        );
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You have view-only inventory access.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTabBar extends StatelessWidget {
  const _InventoryTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(11),
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Spare Parts'),
          Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transactions'),
        ],
      ),
    );
  }
}

class _PartFilters extends StatelessWidget {
  const _PartFilters({
    required this.searchController,
    required this.selectedBrand,
    required this.selectedCategory,
    required this.selectedStockStatus,
    required this.brands,
    required this.categories,
    required this.onSearchChanged,
    required this.onBrandChanged,
    required this.onCategoryChanged,
    required this.onStockStatusChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String selectedBrand;
  final String selectedCategory;
  final String selectedStockStatus;
  final List<String> brands;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStockStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 310,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search spare parts',
                hintText: 'Code, name, brand or category',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          _FilterDropdown(
            width: 180,
            label: 'Brand',
            value: selectedBrand,
            values: brands,
            onChanged: onBrandChanged,
          ),
          _FilterDropdown(
            width: 190,
            label: 'Category',
            value: selectedCategory,
            values: categories,
            onChanged: onCategoryChanged,
          ),
          _FilterDropdown(
            width: 180,
            label: 'Stock status',
            value: selectedStockStatus,
            values: const ['ALL', 'IN_STOCK', 'LOW_STOCK', 'OUT_OF_STOCK'],
            formatter: _formatFilterValue,
            onChanged: onStockStatusChanged,
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}

class _TransactionFilters extends StatelessWidget {
  const _TransactionFilters({
    required this.searchController,
    required this.selectedType,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String selectedType;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 330,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search transactions',
                hintText: 'Part, reference or remarks',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          _FilterDropdown(
            width: 210,
            label: 'Transaction type',
            value: selectedType,
            values: const [
              'ALL',
              InventoryTransactionTypes.stockIn,
              InventoryTransactionTypes.issue,
              InventoryTransactionTypes.stockReturn,
              InventoryTransactionTypes.adjustment,
            ],
            formatter: _formatFilterValue,
            onChanged: onTypeChanged,
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.formatter,
  });

  final double width;
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? formatter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: values.contains(value) ? value : values.first,
            isExpanded: true,
            isDense: true,
            items: values
                .map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      formatter?.call(item) ?? item,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                })
                .toList(growable: false),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _SparePartsTable extends StatelessWidget {
  const _SparePartsTable({
    required this.parts,
    required this.availableWidth,
    required this.canManage,
    required this.onRefresh,
    required this.onView,
    required this.onEdit,
    required this.onStockIn,
    required this.onIssue,
    required this.onReturn,
    required this.onAdjust,
    required this.onDeactivate,
  });

  final List<SparePart> parts;
  final double availableWidth;
  final bool canManage;
  final Future<void> Function() onRefresh;
  final ValueChanged<SparePart> onView;
  final ValueChanged<SparePart> onEdit;
  final ValueChanged<SparePart> onStockIn;
  final ValueChanged<SparePart> onIssue;
  final ValueChanged<SparePart> onReturn;
  final ValueChanged<SparePart> onAdjust;
  final ValueChanged<SparePart> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final minimumWidth = math.max(availableWidth, 1100.0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minimumWidth,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.background),
              columns: const [
                DataColumn(label: Text('Code')),
                DataColumn(label: Text('Part')),
                DataColumn(label: Text('Brand / Category')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Pricing')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: parts
                  .map((part) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            part.partCode,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 185,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  part.partName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _formatUnit(part.unit),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 165,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  part.displayBrand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  part.displayCategory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(_StockBadge(part: part)),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Buy ${_formatCurrency(part.purchasePrice)}',
                                ),
                                Text(
                                  'Sell ${_formatCurrency(part.sellingPrice)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(_ActiveBadge(isActive: part.isActive)),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'View details',
                                onPressed: () {
                                  onView(part);
                                },
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              if (canManage)
                                _PartActionMenu(
                                  part: part,
                                  onEdit: onEdit,
                                  onStockIn: onStockIn,
                                  onIssue: onIssue,
                                  onReturn: onReturn,
                                  onAdjust: onAdjust,
                                  onDeactivate: onDeactivate,
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparePartsCardList extends StatelessWidget {
  const _SparePartsCardList({
    required this.parts,
    required this.canManage,
    required this.onRefresh,
    required this.onView,
    required this.onEdit,
    required this.onStockIn,
    required this.onIssue,
    required this.onReturn,
    required this.onAdjust,
    required this.onDeactivate,
  });

  final List<SparePart> parts;
  final bool canManage;
  final Future<void> Function() onRefresh;
  final ValueChanged<SparePart> onView;
  final ValueChanged<SparePart> onEdit;
  final ValueChanged<SparePart> onStockIn;
  final ValueChanged<SparePart> onIssue;
  final ValueChanged<SparePart> onReturn;
  final ValueChanged<SparePart> onAdjust;
  final ValueChanged<SparePart> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: parts.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          final part = parts[index];

          return _SparePartCard(
            part: part,
            canManage: canManage,
            onView: () {
              onView(part);
            },
            onEdit: () {
              onEdit(part);
            },
            onStockIn: () {
              onStockIn(part);
            },
            onIssue: () {
              onIssue(part);
            },
            onReturn: () {
              onReturn(part);
            },
            onAdjust: () {
              onAdjust(part);
            },
            onDeactivate: () {
              onDeactivate(part);
            },
          );
        },
      ),
    );
  }
}

class _SparePartCard extends StatelessWidget {
  const _SparePartCard({
    required this.part,
    required this.canManage,
    required this.onView,
    required this.onEdit,
    required this.onStockIn,
    required this.onIssue,
    required this.onReturn,
    required this.onAdjust,
    required this.onDeactivate,
  });

  final SparePart part;
  final bool canManage;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onStockIn;
  final VoidCallback onIssue;
  final VoidCallback onReturn;
  final VoidCallback onAdjust;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.partName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${part.partCode} • '
                        '${part.displayBrand}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _StockBadge(part: part),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 16,
              runSpacing: 9,
              children: [
                _InfoText(
                  icon: Icons.category_outlined,
                  text: part.displayCategory,
                ),
                _InfoText(
                  icon: Icons.straighten_outlined,
                  text: _formatUnit(part.unit),
                ),
                _InfoText(
                  icon: Icons.shopping_cart_outlined,
                  text: 'Buy ${_formatCurrency(part.purchasePrice)}',
                ),
                _InfoText(
                  icon: Icons.sell_outlined,
                  text: 'Sell ${_formatCurrency(part.sellingPrice)}',
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _ActiveBadge(isActive: part.isActive),
                const Spacer(),
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                ),
                if (canManage)
                  _PartActionMenu(
                    part: part,
                    onEdit: (_) => onEdit(),
                    onStockIn: (_) => onStockIn(),
                    onIssue: (_) => onIssue(),
                    onReturn: (_) => onReturn(),
                    onAdjust: (_) => onAdjust(),
                    onDeactivate: (_) => onDeactivate(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartActionMenu extends StatelessWidget {
  const _PartActionMenu({
    required this.part,
    required this.onEdit,
    required this.onStockIn,
    required this.onIssue,
    required this.onReturn,
    required this.onAdjust,
    required this.onDeactivate,
  });

  final SparePart part;
  final ValueChanged<SparePart> onEdit;
  final ValueChanged<SparePart> onStockIn;
  final ValueChanged<SparePart> onIssue;
  final ValueChanged<SparePart> onReturn;
  final ValueChanged<SparePart> onAdjust;
  final ValueChanged<SparePart> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PartAction>(
      tooltip: 'Inventory actions',
      onSelected: (action) {
        switch (action) {
          case _PartAction.edit:
            onEdit(part);
          case _PartAction.stockIn:
            onStockIn(part);
          case _PartAction.issue:
            onIssue(part);
          case _PartAction.stockReturn:
            onReturn(part);
          case _PartAction.adjust:
            onAdjust(part);
          case _PartAction.deactivate:
            onDeactivate(part);
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _PartAction.edit,
            child: _MenuItemContent(
              icon: Icons.edit_outlined,
              label: 'Edit Part',
            ),
          ),
          PopupMenuItem(
            value: _PartAction.stockIn,
            child: _MenuItemContent(
              icon: Icons.add_business_outlined,
              label: 'Stock In',
            ),
          ),
          PopupMenuItem(
            value: _PartAction.issue,
            child: _MenuItemContent(
              icon: Icons.outbox_outlined,
              label: 'Issue to Job',
            ),
          ),
          PopupMenuItem(
            value: _PartAction.stockReturn,
            child: _MenuItemContent(
              icon: Icons.assignment_return_outlined,
              label: 'Return from Job',
            ),
          ),
          PopupMenuItem(
            value: _PartAction.adjust,
            child: _MenuItemContent(
              icon: Icons.tune_rounded,
              label: 'Adjust Stock',
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _PartAction.deactivate,
            child: _MenuItemContent(
              icon: Icons.block_rounded,
              label: 'Deactivate',
              color: AppColors.danger,
            ),
          ),
        ];
      },
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.transactions,
    required this.availableWidth,
    required this.onRefresh,
  });

  final List<StockTransaction> transactions;
  final double availableWidth;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final minimumWidth = math.max(availableWidth, 1050.0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minimumWidth,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.background),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Part')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Quantity')),
                DataColumn(label: Text('Reference')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Remarks')),
              ],
              rows: transactions
                  .map((transaction) {
                    return DataRow(
                      cells: [
                        DataCell(Text(_formatDateTime(transaction.createdAt))),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.sparePart.partName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  transaction.sparePart.partCode,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          _TransactionTypeBadge(transaction: transaction),
                        ),
                        DataCell(
                          Text(
                            _signedQuantityText(transaction),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _transactionColor(transaction),
                            ),
                          ),
                        ),
                        DataCell(Text(transaction.displayReference)),
                        DataCell(Text(_formatCurrency(transaction.lineTotal))),
                        DataCell(
                          SizedBox(
                            width: 190,
                            child: Text(
                              transaction.displayRemarks,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionsCardList extends StatelessWidget {
  const _TransactionsCardList({
    required this.transactions,
    required this.onRefresh,
  });

  final List<StockTransaction> transactions;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: transactions.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          final transaction = transactions[index];

          return Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.sparePart.partName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _TransactionTypeBadge(transaction: transaction),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.sparePart.partCode} • '
                    '${_formatDateTime(transaction.createdAt)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      _InfoText(
                        icon: Icons.numbers_rounded,
                        text: 'Qty ${_signedQuantityText(transaction)}',
                        color: _transactionColor(transaction),
                      ),
                      _InfoText(
                        icon: Icons.currency_rupee_rounded,
                        text: _formatCurrency(transaction.lineTotal),
                      ),
                      _InfoText(
                        icon: Icons.receipt_outlined,
                        text: transaction.displayReference,
                      ),
                    ],
                  ),
                  if (transaction.displayRemarks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      transaction.displayRemarks,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.part});

  final SparePart part;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (part.isOutOfStock) {
      color = AppColors.danger;
      label = 'Out of stock';
    } else if (part.isLowStock) {
      color = AppColors.warning;
      label = 'Low stock';
    } else {
      color = AppColors.success;
      label = 'In stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${part.currentStock} • $label',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TransactionTypeBadge extends StatelessWidget {
  const _TransactionTypeBadge({required this.transaction});

  final StockTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = _transactionColor(transaction);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatFilterValue(transaction.transactionType),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: effectiveColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: effectiveColor,
            fontWeight: color == null ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MenuItemContent extends StatelessWidget {
  const _MenuItemContent({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 11),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _SparePartDetailsDialog extends StatelessWidget {
  const _SparePartDetailsDialog({
    required this.sparePart,
    required this.canManage,
    required this.onEdit,
    required this.onStockIn,
    required this.onIssue,
    required this.onReturn,
    required this.onAdjust,
  });

  final SparePart sparePart;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onStockIn;
  final VoidCallback onIssue;
  final VoidCallback onReturn;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: MediaQuery.sizeOf(context).height - 40,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sparePart.partName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          sparePart.partCode,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DetailsGrid(sparePart: sparePart),
              const SizedBox(height: 22),
              Text(
                'Stock valuation',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ValueTile(
                    width: screenWidth < 600 ? double.infinity : 180,
                    label: 'Purchase value',
                    value: _formatCurrency(sparePart.currentPurchaseValue),
                  ),
                  _ValueTile(
                    width: screenWidth < 600 ? double.infinity : 180,
                    label: 'Selling value',
                    value: _formatCurrency(sparePart.currentSellingValue),
                  ),
                  _ValueTile(
                    width: screenWidth < 600 ? double.infinity : 180,
                    label: 'Margin per unit',
                    value: _formatCurrency(sparePart.expectedMarginPerUnit),
                  ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    FilledButton.icon(
                      onPressed: onStockIn,
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Stock In'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onIssue,
                      icon: const Icon(Icons.outbox_outlined),
                      label: const Text('Issue'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onReturn,
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('Return'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onAdjust,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Adjust'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.sparePart});

  final SparePart sparePart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 500
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DetailTile(
              width: itemWidth,
              label: 'Brand',
              value: sparePart.displayBrand,
            ),
            _DetailTile(
              width: itemWidth,
              label: 'Category',
              value: sparePart.displayCategory,
            ),
            _DetailTile(
              width: itemWidth,
              label: 'Current stock',
              value: '${sparePart.currentStock} ${_formatUnit(sparePart.unit)}',
            ),
            _DetailTile(
              width: itemWidth,
              label: 'Minimum stock',
              value: '${sparePart.minimumStock} ${_formatUnit(sparePart.unit)}',
            ),
            _DetailTile(
              width: itemWidth,
              label: 'Purchase price',
              value: _formatCurrency(sparePart.purchasePrice),
            ),
            _DetailTile(
              width: itemWidth,
              label: 'Selling price',
              value: _formatCurrency(sparePart.sellingPrice),
            ),
          ],
        );
      },
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: AppColors.textSecondary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _PartAction { edit, stockIn, issue, stockReturn, adjust, deactivate }

bool _matchesStockFilter(SparePart part, String filter) {
  switch (filter) {
    case 'IN_STOCK':
      return !part.isLowStock;
    case 'LOW_STOCK':
      return part.isLowStock && !part.isOutOfStock;
    case 'OUT_OF_STOCK':
      return part.isOutOfStock;
    default:
      return true;
  }
}

int _sortFilterValues(String first, String second) {
  if (first == 'ALL') {
    return -1;
  }

  if (second == 'ALL') {
    return 1;
  }

  return first.toLowerCase().compareTo(second.toLowerCase());
}

Color _transactionColor(StockTransaction transaction) {
  if (transaction.isStockIn || transaction.isReturn) {
    return AppColors.success;
  }

  if (transaction.isIssue) {
    return AppColors.danger;
  }

  if (transaction.quantity > 0) {
    return AppColors.info;
  }

  if (transaction.quantity < 0) {
    return AppColors.warning;
  }

  return AppColors.textSecondary;
}

String _signedQuantityText(StockTransaction transaction) {
  final quantity = transaction.signedQuantity;

  if (quantity > 0) {
    return '+$quantity';
  }

  return '$quantity';
}

String _formatCurrency(double value) {
  return '₹${value.toStringAsFixed(2)}';
}

String _formatUnit(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('_', ' ');

  if (normalized.isEmpty) {
    return 'units';
  }

  return normalized;
}

String _formatFilterValue(String value) {
  if (value == 'ALL') {
    return 'All';
  }

  return value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) {
        return '${word[0].toUpperCase()}'
            '${word.substring(1)}';
      })
      .join(' ');
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');

  final month = local.month.toString().padLeft(2, '0');

  final hour = local.hour.toString().padLeft(2, '0');

  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/${local.year} '
      '$hour:$minute';
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
