import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../providers/attendance_provider.dart';

class EmployeeAttendanceDetailScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const EmployeeAttendanceDetailScreen({
    super.key,
    required this.employeeId,
  });

  @override
  ConsumerState<EmployeeAttendanceDetailScreen> createState() => _EmployeeAttendanceDetailScreenState();
}

class _EmployeeAttendanceDetailScreenState extends ConsumerState<EmployeeAttendanceDetailScreen> {
  DateTime _selectedMonth = DateTime.now();

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year < now.year || (_selectedMonth.year == now.year && _selectedMonth.month < now.month)) {
      setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Fetch Employee profile details
    final employeeAsync = ref.watch(employeeStreamProvider(widget.employeeId));

    // Fetch monthly summary scorecard
    final summaryAsync = ref.watch(monthlySummaryProvider((
      employeeId: widget.employeeId,
      month: _selectedMonth,
    )));

    // Fetch attendance logs
    final historyAsync = ref.watch(employeeAttendanceHistoryProvider(widget.employeeId));

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Employee Timesheet Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Details Header Card
                employeeAsync.when(
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading employee info: $e')),
                  data: (emp) {
                    if (emp == null) {
                      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Employee profile not found.')));
                    }
                    return _buildEmployeeProfileCard(theme, emp);
                  },
                ),
                const SizedBox(height: AppSizes.p24),

                // Month Picker Banner
                _buildMonthPickerBanner(theme),
                const SizedBox(height: AppSizes.p24),

                // Monthly Scorecard Metrics
                summaryAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
                  data: (summary) => _buildMetricsGrid(context, summary),
                ),
                const SizedBox(height: AppSizes.p32),

                // Daily Logs list
                Text(
                  'Daily Calendar Logs',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSizes.p12),

                historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading logs: $e'),
                  data: (records) {
                    final monthRecords = records
                        .where((r) => r.date.month == _selectedMonth.month && r.date.year == _selectedMonth.year)
                        .toList();

                    if (monthRecords.isEmpty) {
                      return _buildEmptyState(theme);
                    }

                    // Sort chronologically ascending
                    monthRecords.sort((a, b) => a.date.compareTo(b.date));

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Check-In')),
                              DataColumn(label: Text('Check-Out')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Working Hours')),
                              DataColumn(label: Text('Remarks')),
                            ],
                            rows: monthRecords.map((rec) {
                              final inStr = rec.checkInTime != null ? DateFormat('hh:mm a').format(rec.checkInTime!) : '--:--';
                              final outStr = rec.checkOutTime != null ? DateFormat('hh:mm a').format(rec.checkOutTime!) : '--:--';
                              return DataRow(
                                cells: [
                                  DataCell(Text(DateFormat('dd EEE').format(rec.date))),
                                  DataCell(Text(inStr)),
                                  DataCell(Text(outStr)),
                                  DataCell(_buildStatusChip(rec.status)),
                                  DataCell(Text('${rec.workingHours.toStringAsFixed(1)} hrs')),
                                  DataCell(Text(rec.remarks ?? 'N/A')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeProfileCard(ThemeData theme, dynamic emp) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primary.withAlpha(26),
              child: Text(
                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                style: TextStyle(fontSize: 28, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSizes.p20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        emp.name,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: emp.status == 'Active' ? AppColors.success.withAlpha(38) : AppColors.error.withAlpha(38),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          emp.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: emp.status == 'Active' ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${emp.designation} | ${emp.department}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Email: ${emp.email} | Phone: ${emp.phone}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  Text(
                    'Employee ID: ${emp.employeeId} | Joined: ${DateFormat('yyyy-MM-dd').format(emp.joiningDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPickerBanner(ThemeData theme) {
    final now = DateTime.now();
    final isLatest = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.colorScheme.primary.withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: _previousMonth,
              color: theme.colorScheme.primary,
            ),
            Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              onPressed: isLatest ? null : _nextMonth,
              color: isLatest ? Colors.grey : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, dynamic summary) {
    final metrics = [
      _MetricItemData('Attendance Rate', '${summary.attendancePercentage.toStringAsFixed(1)}%', AppColors.success, Icons.percent_rounded),
      _MetricItemData('Total Hours Worked', '${summary.totalWorkingHours.toStringAsFixed(1)} hrs', Colors.blue, Icons.timer_rounded),
      _MetricItemData('Present Days', '${summary.presentDays} Days', AppColors.success, Icons.check_circle_outline_rounded),
      _MetricItemData('Absent Days', '${summary.absentDays} Days', AppColors.error, Icons.cancel_outlined),
      _MetricItemData('Half Days', '${summary.halfDays} Days', Colors.orange, Icons.hourglass_bottom_rounded),
      _MetricItemData('Leaves Taken', '${summary.leaveDays} Days', Colors.purple, Icons.time_to_leave_rounded),
      _MetricItemData('Expected Days', '${summary.totalWorkingDays} Days', Colors.indigo, Icons.calendar_month_rounded),
      _MetricItemData('Holidays', '${summary.holidays} Days', Colors.teal, Icons.beach_access_rounded),
    ];

    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);
    final mainExtent = isMobile ? 120.0 : (isTablet ? 120.0 : 100.0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: mainExtent,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final item = metrics[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: AppSizes.p8),
            child: Row(
              children: [
                Icon(item.icon, color: item.color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color statusColor = Colors.grey;
    final stat = status.toLowerCase();
    if (stat == 'present') statusColor = AppColors.success;
    if (stat == 'absent') statusColor = AppColors.error;
    if (stat == 'late') statusColor = AppColors.warning;
    if (stat == 'half day') statusColor = Colors.orange;
    if (stat == 'leave') statusColor = Colors.purple;
    if (stat == 'holiday') statusColor = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(77)),
      ),
      child: Text(
        status,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          children: [
            Icon(Icons.calendar_today_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: AppSizes.p12),
            Text(
              'No attendance logs found for this month.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItemData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  _MetricItemData(this.label, this.value, this.color, this.icon);
}
