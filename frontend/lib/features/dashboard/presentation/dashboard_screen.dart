import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/dashboard_model.dart';
import '../data/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);

    return dashboardState.when(
      data: (overview) {
        return _DashboardContent(
          overview: overview,
          onRefresh: () {
            return ref.read(dashboardProvider.notifier).refreshDashboard();
          },
        );
      },
      loading: () => const _DashboardLoading(),
      error: (error, stackTrace) {
        return _DashboardError(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () {
            ref.read(dashboardProvider.notifier).refreshDashboard();
          },
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.overview, required this.onRefresh});

  final DashboardOverview overview;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = overview.summary;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pagePadding = constraints.maxWidth < 600 ? 16.0 : 24.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(onRefresh: onRefresh),
                const SizedBox(height: 24),
                _SummaryGrid(
                  summary: summary,
                  availableWidth: constraints.maxWidth,
                ),
                const SizedBox(height: 24),
                _ResponsiveRow(
                  firstFlex: 2,
                  secondFlex: 1,
                  first: _RevenueChartCard(points: overview.revenueLast7Days),
                  second: _JobStatusChartCard(statuses: overview.jobStatuses),
                ),
                const SizedBox(height: 24),
                _ResponsiveRow(
                  firstFlex: 2,
                  secondFlex: 1,
                  first: _RecentRequestsCard(
                    requests: overview.recentServiceRequests,
                  ),
                  second: _LowStockCard(parts: overview.lowStockParts),
                ),
                const SizedBox(height: 24),
                _ResponsiveRow(
                  first: _ServiceStatusCard(
                    statuses: overview.serviceRequestStatuses,
                  ),
                  second: _TechnicianWorkloadCard(
                    technicians: overview.technicianWorkload,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Service Centre Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Live operational data from your ASC Manager backend.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 15,
                ),
              ),
            ],
          );

          final refreshButton = OutlinedButton.icon(
            onPressed: () {
              onRefresh();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Refresh',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textContent,
                const SizedBox(height: 20),
                refreshButton,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: textContent),
              const SizedBox(width: 20),
              refreshButton,
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.availableWidth});

  final DashboardSummary summary;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = availableWidth >= 1350
        ? 4
        : availableWidth >= 700
        ? 2
        : 1;

    final childAspectRatio = availableWidth >= 1350
        ? 2.15
        : availableWidth >= 700
        ? 2.4
        : 2.55;

    final cards = [
      _SummaryData(
        title: 'Total Customers',
        value: summary.totalCustomers.toString(),
        subtitle: 'Registered customers',
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
      ),
      _SummaryData(
        title: 'Open Requests',
        value: summary.openServiceRequests.toString(),
        subtitle: '${summary.totalServiceRequests} total requests',
        icon: Icons.support_agent_rounded,
        color: AppColors.info,
      ),
      _SummaryData(
        title: 'Active Jobs',
        value: summary.activeJobs.toString(),
        subtitle: '${summary.completedJobs} completed',
        icon: Icons.engineering_rounded,
        color: AppColors.warning,
      ),
      _SummaryData(
        title: 'Delivered Jobs',
        value: summary.deliveredJobs.toString(),
        subtitle: 'Successfully delivered',
        icon: Icons.local_shipping_rounded,
        color: AppColors.success,
      ),
      _SummaryData(
        title: 'Total Revenue',
        value: _formatCurrency(summary.totalRevenue),
        subtitle: 'Successful payments',
        icon: Icons.currency_rupee_rounded,
        color: AppColors.success,
      ),
      _SummaryData(
        title: 'Available Technicians',
        value: summary.activeTechnicians.toString(),
        subtitle: '${summary.techniciansWithActiveJobs} handling active jobs',
        icon: Icons.person_search_rounded,
        color: AppColors.secondary,
      ),
      _SummaryData(
        title: 'Low Stock Parts',
        value: summary.lowStockParts.toString(),
        subtitle: summary.lowStockParts == 0
            ? 'Stock levels are healthy'
            : 'Requires attention',
        icon: Icons.inventory_2_rounded,
        color: summary.lowStockParts == 0
            ? AppColors.success
            : AppColors.danger,
      ),
      _SummaryData(
        title: 'Pending Invoices',
        value: summary.unpaidInvoices.toString(),
        subtitle: '${summary.partiallyPaidInvoices} partially paid',
        icon: Icons.receipt_long_rounded,
        color: AppColors.danger,
      ),
    ];

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return _SummaryCard(data: cards[index]);
      },
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(data.icon, color: data.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({
    required this.first,
    required this.second,
    this.firstFlex = 1,
    this.secondFlex = 1,
  });

  final Widget first;
  final Widget second;
  final int firstFlex;
  final int secondFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: firstFlex, child: first),
            const SizedBox(width: 16),
            Expanded(flex: secondFlex, child: second),
          ],
        );
      },
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final highestAmount = points.fold<double>(
      0,
      (current, point) => math.max(current, point.amount),
    );

    final double chartMaximum = highestAmount <= 0 ? 100 : highestAmount * 1.25;

    final double interval = chartMaximum <= 100 ? 25.0 : chartMaximum / 4;

    return _DashboardCard(
      title: 'Revenue – Last 7 Days',
      subtitle: 'Successful payment collection by day',
      child: SizedBox(
        height: 270,
        child: points.isEmpty
            ? const _EmptyState(
                icon: Icons.show_chart_rounded,
                message: 'No revenue information available.',
              )
            : LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: chartMaximum,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: AppColors.border,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _compactCurrency(value),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _weekdayName(points[index].date),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            _formatCurrency(spot.y),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var index = 0; index < points.length; index++)
                          FlSpot(index.toDouble(), points[index].amount),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _JobStatusChartCard extends StatelessWidget {
  const _JobStatusChartCard({required this.statuses});

  final List<StatusCount> statuses;

  static const colors = [
    AppColors.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.info,
    AppColors.secondary,
    AppColors.danger,
    Color(0xFF14B8A6),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleStatuses = statuses.where((item) => item.count > 0).toList();

    final total = visibleStatuses.fold<int>(
      0,
      (current, item) => current + item.count,
    );

    return _DashboardCard(
      title: 'Job Status',
      subtitle: '$total job cards',
      child: SizedBox(
        height: 270,
        child: visibleStatuses.isEmpty
            ? const _EmptyState(
                icon: Icons.donut_large_rounded,
                message: 'No job cards available.',
              )
            : Column(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 48,
                        sectionsSpace: 3,
                        sections: [
                          for (
                            var index = 0;
                            index < visibleStatuses.length;
                            index++
                          )
                            PieChartSectionData(
                              value: visibleStatuses[index].count.toDouble(),
                              color: colors[index % colors.length],
                              radius: 56,
                              title: '${visibleStatuses[index].count}',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (
                        var index = 0;
                        index < visibleStatuses.length;
                        index++
                      )
                        _LegendItem(
                          color: colors[index % colors.length],
                          text: _formatStatus(visibleStatuses[index].status),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _RecentRequestsCard extends StatelessWidget {
  const _RecentRequestsCard({required this.requests});

  final List<RecentServiceRequest> requests;

  @override
  Widget build(BuildContext context) {
    final visibleRequests = requests.take(6).toList();

    return _DashboardCard(
      title: 'Recent Service Requests',
      subtitle: 'Latest registered complaints',
      child: visibleRequests.isEmpty
          ? const SizedBox(
              height: 230,
              child: _EmptyState(
                icon: Icons.build_circle_outlined,
                message: 'No service requests available.',
              ),
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < visibleRequests.length;
                  index++
                ) ...[
                  _ServiceRequestTile(request: visibleRequests[index]),
                  if (index < visibleRequests.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _ServiceRequestTile extends StatelessWidget {
  const _ServiceRequestTile({required this.request});

  final RecentServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.home_repair_service_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.requestCode,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusBadge(
                      label: _formatStatus(request.status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  request.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${request.brand} ${request.productName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatStatus(request.complaintCategory)} • '
                  '${_formatStatus(request.priority)} priority',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.parts});

  final List<LowStockPart> parts;

  @override
  Widget build(BuildContext context) {
    final visibleParts = parts.take(6).toList();

    return _DashboardCard(
      title: 'Low Stock Alerts',
      subtitle: '${parts.length} items require attention',
      child: visibleParts.isEmpty
          ? const SizedBox(
              height: 230,
              child: _EmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'All stock levels are healthy.',
                color: AppColors.success,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < visibleParts.length; index++) ...[
                  _LowStockTile(part: visibleParts[index]),
                  if (index < visibleParts.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.part});

  final LowStockPart part;

  @override
  Widget build(BuildContext context) {
    final isEmpty = part.currentStock <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEmpty
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.partName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${part.partCode}'
                  '${part.brand == null || part.brand!.isEmpty ? '' : ' • ${part.brand}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${part.currentStock} ${part.unit}',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Min: ${part.minimumStock}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceStatusCard extends StatelessWidget {
  const _ServiceStatusCard({required this.statuses});

  final List<StatusCount> statuses;

  @override
  Widget build(BuildContext context) {
    final maximum = statuses.fold<int>(
      1,
      (current, item) => math.max(current, item.count),
    );

    return _DashboardCard(
      title: 'Service Request Status',
      subtitle: 'Complaint workflow overview',
      child: statuses.isEmpty
          ? const SizedBox(
              height: 210,
              child: _EmptyState(
                icon: Icons.analytics_outlined,
                message: 'No service status data available.',
              ),
            )
          : Column(
              children: [
                for (final item in statuses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatStatus(item.status),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              item.count.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: item.count / maximum,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(
                              _statusColor(item.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TechnicianWorkloadCard extends StatelessWidget {
  const _TechnicianWorkloadCard({required this.technicians});

  final List<TechnicianWorkload> technicians;

  @override
  Widget build(BuildContext context) {
    final visibleTechnicians = technicians.take(8).toList();

    final maximumJobs = visibleTechnicians.fold<int>(
      1,
      (current, technician) => math.max(current, technician.activeJobs),
    );

    return _DashboardCard(
      title: 'Technician Workload',
      subtitle: '${technicians.length} active technicians',
      child: visibleTechnicians.isEmpty
          ? const SizedBox(
              height: 210,
              child: _EmptyState(
                icon: Icons.engineering_outlined,
                message: 'No active technicians available.',
              ),
            )
          : Column(
              children: [
                for (final technician in visibleTechnicians)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            technician.technicianName.trim().isEmpty
                                ? 'T'
                                : technician.technicianName
                                      .trim()[0]
                                      .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      technician.technicianName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _StatusBadge(
                                    label: _formatStatus(
                                      technician.availabilityStatus,
                                    ),
                                    color: _statusColor(
                                      technician.availabilityStatus,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              LinearProgressIndicator(
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(20),
                                value: technician.activeJobs / maximumJobs,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${technician.activeJobs} active jobs • '
                                '${technician.technicianCode}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: color),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text(
            'Loading dashboard...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.danger,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unable to load dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCurrency(double amount) {
  final rounded = amount.round().toString();
  final formatted = rounded.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  return '₹$formatted';
}

String _compactCurrency(double amount) {
  if (amount >= 10000000) {
    return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
  }

  if (amount >= 100000) {
    return '₹${(amount / 100000).toStringAsFixed(1)}L';
  }

  if (amount >= 1000) {
    return '₹${(amount / 1000).toStringAsFixed(1)}K';
  }

  return '₹${amount.toStringAsFixed(0)}';
}

String _weekdayName(DateTime date) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  return names[date.weekday - 1];
}

String _formatStatus(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'AVAILABLE':
    case 'SUCCESS':
    case 'COMPLETED':
    case 'DELIVERED':
    case 'PAID':
    case 'ACTIVE':
      return AppColors.success;

    case 'BUSY':
    case 'ASSIGNED':
    case 'ACCEPTED':
    case 'DIAGNOSIS':
    case 'REPAIR_IN_PROGRESS':
    case 'TESTING':
      return AppColors.primary;

    case 'OPEN':
    case 'PENDING':
    case 'WAITING_PARTS':
    case 'PARTIALLY_PAID':
      return AppColors.warning;

    case 'FAILED':
    case 'CANCELLED':
    case 'REJECTED':
    case 'UNPAID':
    case 'INACTIVE':
      return AppColors.danger;

    default:
      return AppColors.info;
  }
}
