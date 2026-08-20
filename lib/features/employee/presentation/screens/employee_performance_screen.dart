import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/performance_provider.dart';
import '../../domain/models/performance_history_model.dart';

class EmployeePerformanceScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const EmployeePerformanceScreen({
    super.key,
    required this.employeeId,
  });

  @override
  ConsumerState<EmployeePerformanceScreen> createState() => _EmployeePerformanceScreenState();
}

class _EmployeePerformanceScreenState extends ConsumerState<EmployeePerformanceScreen> {
  PerformanceFilter _selectedFilter = PerformanceFilter.longTerm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final employeeAsync = ref.watch(employeeStreamProvider(widget.employeeId));
    final historyAsync = ref.watch(performanceHistoryStreamProvider(widget.employeeId));

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Performance Analytics'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading employee profile: $err')),
        data: (employee) {
          if (employee == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: AppSizes.p16),
                  Text('Employee Profile Not Found', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSizes.p16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final stats = ref.watch(performanceStatsProvider((employeeId: widget.employeeId, filter: _selectedFilter)));
          final filteredHistory = ref.watch(filteredPerformanceHistoryProvider((employeeId: widget.employeeId, filter: _selectedFilter)));

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Summary Header Card
                      _buildEmployeeHeaderCard(theme, employee, isDark),
                      const SizedBox(height: AppSizes.p24),

                      // Time range Filter Tabs
                      _buildFilterRow(theme),
                      const SizedBox(height: AppSizes.p20),

                      // Key Performance Indicators Grid
                      _buildStatsGrid(theme, stats, isDark),
                      const SizedBox(height: AppSizes.p32),

                      // Tasks Performance History Title
                      Text(
                        'Completed Tasks History (${filteredHistory.length})',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),

                      // List of Performance History Records
                      if (filteredHistory.isEmpty)
                        _buildEmptyHistory(theme)
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredHistory.length,
                          itemBuilder: (context, index) {
                            final item = filteredHistory[index];
                            return _PerformanceHistoryCard(item: item, isDark: isDark);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmployeeHeaderCard(ThemeData theme, dynamic employee, bool isDark) {
    final initials = employee.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primary.withAlpha(25),
              child: Text(
                initials.isNotEmpty ? initials : 'E',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.p20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${employee.designation} • ${employee.department}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Employee ID: ${employee.employeeId}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: PerformanceFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          String label = "";
          switch (filter) {
            case PerformanceFilter.daily:
              label = "Daily (Today)";
              break;
            case PerformanceFilter.weekly:
              label = "Weekly (7d)";
              break;
            case PerformanceFilter.monthly:
              label = "Monthly (30d)";
              break;
            case PerformanceFilter.longTerm:
              label = "Long-term (All)";
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: theme.colorScheme.primary.withAlpha(40),
              labelStyle: TextStyle(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme, PerformanceStats stats, bool isDark) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 2
        : ResponsiveLayout.isTablet(context)
            ? 3
            : 4;

    final items = [
      _StatItem(
        label: 'Average Score',
        value: '${stats.averageScore.toStringAsFixed(1)}/100',
        icon: Icons.star_rounded,
        color: stats.averageScore >= 80
            ? AppColors.success
            : (stats.averageScore >= 50 ? Colors.orange : AppColors.error),
      ),
      _StatItem(
        label: 'Completed Tasks',
        value: '${stats.completedTasks}',
        icon: Icons.task_alt_rounded,
        color: theme.colorScheme.primary,
      ),
      _StatItem(
        label: 'Early Tasks',
        value: '${stats.earlyTasks}',
        icon: Icons.speed_rounded,
        color: Colors.teal,
      ),
      _StatItem(
        label: 'On-Time Tasks',
        value: '${stats.onTimeTasks}',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
      ),
      _StatItem(
        label: 'Late Tasks',
        value: '${stats.lateTasks}',
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
      ),
      _StatItem(
        label: 'Avg Completion Time',
        value: '${stats.averageCompletionTimeMinutes.toStringAsFixed(0)}m',
        icon: Icons.access_time_rounded,
        color: Colors.purple,
      ),
      _StatItem(
        label: 'Total Late Minutes',
        value: '${stats.totalLateMinutes}m',
        icon: Icons.hourglass_bottom_rounded,
        color: Colors.deepOrange,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p12,
        mainAxisSpacing: AppSizes.p12,
        mainAxisExtent: 110,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withAlpha(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(item.icon, color: item.color, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistory(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withAlpha(30)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSizes.p32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No completed tasks found for this period',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _PerformanceHistoryCard extends StatefulWidget {
  final PerformanceHistoryModel item;
  final bool isDark;

  const _PerformanceHistoryCard({
    required this.item,
    required this.isDark,
  });

  @override
  State<_PerformanceHistoryCard> createState() => _PerformanceHistoryCardState();
}

class _PerformanceHistoryCardState extends State<_PerformanceHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    final timingColor = item.completionTiming == 'Early'
        ? Colors.teal
        : (item.completionTiming == 'Late' ? AppColors.error : AppColors.success);

    final ratingColor = item.performanceScore >= 90
        ? Colors.teal
        : (item.performanceScore >= 70 ? Colors.indigo : (item.performanceScore >= 50 ? Colors.orange : AppColors.error));

    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.p12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withAlpha(_expanded ? 60 : 30)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            title: Text(
              item.taskName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  if (item.machine.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.machine,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    item.department,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timing badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: timingColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: timingColor, width: 0.5),
                  ),
                  child: Text(
                    item.completionTiming,
                    style: TextStyle(color: timingColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                // Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ratingColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${item.performanceScore}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timing details
                  _buildDetailRow('Assigned Date/Time', dateFormat.format(item.assignedDate)),
                  if (item.startDate != null)
                    _buildDetailRow('Start Date/Time', dateFormat.format(item.startDate!)),
                  if (item.estimatedCompletionTime != null)
                    _buildDetailRow('Est. Completion Time', dateFormat.format(item.estimatedCompletionTime!)),
                  _buildDetailRow('Allowed Duration', '${item.allowedTime} mins'),
                  if (item.actualCompletionTime != null)
                    _buildDetailRow('Actual Completion Time', dateFormat.format(item.actualCompletionTime!)),
                  _buildDetailRow('Total Time Taken', '${item.totalTimeTaken} mins'),

                  if (item.completionTiming == 'Late') ...[
                    _buildDetailRow('Late Duration', '${item.lateDuration} mins', color: AppColors.error),
                    _buildDetailRow('Late Reason', item.lateReason, color: AppColors.error),
                  ],

                  _buildDetailRow('Performance Rating', item.performanceRating, color: ratingColor, isBold: true),

                  // Selected tooling chips
                  if (item.selectedTooling.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Selected Tooling:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.selectedTooling.map((tool) {
                        return Chip(
                          label: Text(tool, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.dividerColor.withAlpha(40)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: 13.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
