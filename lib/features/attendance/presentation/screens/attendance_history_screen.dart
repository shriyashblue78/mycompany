import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../providers/attendance_provider.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _activePreset = 'AllTime';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final role = authState.selectedRole;
      if (role == 'Employee') {
        ref.read(historyEmployeeFilterProvider.notifier).state = authState.user?.employeeId;
      } else {
        ref.read(historyEmployeeFilterProvider.notifier).state = 'All';
      }
      _resetFilters();
    });
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _activePreset = 'AllTime';
    });
    ref.read(historyStartDateProvider.notifier).state = null;
    ref.read(historyEndDateProvider.notifier).state = null;
  }

  void _applyWeeklyPreset() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      _startDate = start;
      _endDate = now;
      _activePreset = 'Weekly';
    });
    ref.read(historyStartDateProvider.notifier).state = start;
    ref.read(historyEndDateProvider.notifier).state = now;
  }

  void _applyMonthlyPreset() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    setState(() {
      _startDate = start;
      _endDate = now;
      _activePreset = 'Monthly';
    });
    ref.read(historyStartDateProvider.notifier).state = start;
    ref.read(historyEndDateProvider.notifier).state = now;
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _activePreset = 'Custom';
      });
      ref.read(historyStartDateProvider.notifier).state = picked.start;
      ref.read(historyEndDateProvider.notifier).state = picked.end;
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(filteredHistoryProvider);
    final employeesAsync = ref.watch(allActiveEmployeesProvider);
    final theme = Theme.of(context);

    final role = ref.watch(authProvider).selectedRole ?? 'Employee';
    final isStaff = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    final selectedEmployeeId = ref.watch(historyEmployeeFilterProvider);
    final startDate = ref.watch(historyStartDateProvider);
    final endDate = ref.watch(historyEndDateProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
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
                // Filter Panel Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.p16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter Records',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSizes.p12),

                        // Employee Filter Dropdown (HR/Owner only)
                        if (isStaff) ...[
                          employeesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error loading employees: $e'),
                            data: (employees) {
                              return DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: selectedEmployeeId ?? 'All',
                                decoration: InputDecoration(
                                  labelText: 'Select Employee',
                                  prefixIcon: const Icon(Icons.person_outline_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: [
                                  const DropdownMenuItem(value: 'All', child: Text('All Employees')),
                                  ...employees.map(
                                    (e) => DropdownMenuItem(
                                      value: e.employeeId,
                                      child: Text('${e.name} (${e.employeeId})'),
                                    ),
                                  )
                                ],
                                onChanged: (val) {
                                  ref.read(historyEmployeeFilterProvider.notifier).state = val;
                                },
                              );
                            },
                          ),
                          const SizedBox(height: AppSizes.p12),
                        ],

                        // Preset buttons
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPresetButton('All Time', _activePreset == 'AllTime', _resetFilters),
                            _buildPresetButton('This Week', _activePreset == 'Weekly', _applyWeeklyPreset),
                            _buildPresetButton('This Month', _activePreset == 'Monthly', _applyMonthlyPreset),
                            _buildPresetButton('Custom Range', _activePreset == 'Custom', _selectCustomRange),
                          ],
                        ),

                        if (startDate != null && endDate != null) ...[
                          const SizedBox(height: AppSizes.p12),
                          Row(
                            children: [
                              const Icon(Icons.date_range_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Showing: ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p24),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance Logs',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    historyAsync.when(
                      data: (list) => Text(
                        'Total Logs: ${list.length}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                      loading: () => const SizedBox(),
                      error: (e, _) => const SizedBox(),
                    )
                  ],
                ),
                const SizedBox(height: AppSizes.p12),

                // History Records List
                historyAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
                  data: (records) {
                    if (records.isEmpty) {
                      return _buildEmptyState(theme);
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: records.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
                      itemBuilder: (context, index) {
                        final rec = records[index];
                        return _buildHistoryCard(context, theme, rec, isStaff);
                      },
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

  Widget _buildPresetButton(String label, bool isActive, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? Theme.of(context).colorScheme.primary.withAlpha(20) : null,
        side: BorderSide(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
          width: isActive ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, ThemeData theme, JoinedAttendanceRecord record, bool isStaff) {
    Color statusColor = Colors.grey;
    final status = record.attendance.status.toLowerCase();
    if (status == 'present') statusColor = AppColors.success;
    if (status == 'absent') statusColor = AppColors.error;
    if (status == 'late') statusColor = AppColors.warning;
    if (status == 'half day') statusColor = Colors.orange;
    if (status == 'leave') statusColor = Colors.purple;
    if (status == 'holiday') statusColor = Colors.blue;

    final inTime = record.attendance.checkInTime != null 
        ? DateFormat('hh:mm a').format(record.attendance.checkInTime!) 
        : '--:--';
    final outTime = record.attendance.checkOutTime != null 
        ? DateFormat('hh:mm a').format(record.attendance.checkOutTime!) 
        : '--:--';

    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('dd MMM').format(record.attendance.date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isStaff 
                            ? record.employee.name 
                            : DateFormat('EEEE').format(record.attendance.date),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withAlpha(128)),
                    ),
                    child: Text(
                      record.attendance.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              if (isStaff) ...[
                Text(
                  'ID: ${record.employee.employeeId} | ${record.employee.department}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.login, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('In: $inTime', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('Out: $outTime', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  if (record.attendance.workingHours > 0)
                    Text(
                      '${record.attendance.workingHours.toStringAsFixed(1)} hrs',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              if (record.attendance.remarks != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Remarks: ${record.attendance.remarks}',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Row(
          children: [
            // Date badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('dd').format(record.attendance.date),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(record.attendance.date).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.p16),

            // Timings & Employee details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isStaff) ...[
                    Text(
                      record.employee.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ID: ${record.employee.employeeId} | ${record.employee.department}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  ] else ...[
                    Text(
                      DateFormat('EEEE').format(record.attendance.date),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.login, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('In: $inTime', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('Out: $outTime', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  if (record.attendance.remarks != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Remarks: ${record.attendance.remarks}',
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                    ),
                  ]
                ],
              ),
            ),

            // Status Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(128)),
                  ),
                  child: Text(
                    record.attendance.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                if (record.attendance.workingHours > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${record.attendance.workingHours.toStringAsFixed(1)} hrs',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No attendance logs found for this filter combination.',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
