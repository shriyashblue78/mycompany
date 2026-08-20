import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/attendance_provider.dart';

class TodaysAttendanceScreen extends ConsumerWidget {
  const TodaysAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    
    final role = authState.selectedRole ?? 'Employee';
    final isStaff = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(isStaff ? "Today's Attendance Audits" : "My Today's Time Card"),
        elevation: 0,
      ),
      body: isStaff ? _buildStaffView(context, ref, theme) : _buildEmployeeView(context, ref, theme),
    );
  }

  // --- STAFF VIEW ---
  Widget _buildStaffView(BuildContext context, WidgetRef ref, ThemeData theme) {
    final searchResultsAsync = ref.watch(searchedAttendanceProvider);
    final statsAsync = ref.watch(todayAttendanceStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Card Row
              statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (stats) => _buildStatsRow(context, stats),
              ),
              const SizedBox(height: AppSizes.p24),

              // Filter Controls
              _buildFilterBar(context, ref, theme),
              const SizedBox(height: AppSizes.p16),

              // Attendance List
              Text(
                'Workforce Records',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSizes.p12),

              searchResultsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading data: $e')),
                data: (records) {
                  if (records.isEmpty) {
                    return _buildEmptyState(theme, 'No records found matching filters.');
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: records.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return _buildRecordCard(context, theme, record);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AttendanceStats stats) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final columns = isMobile ? 2 : 4;
    final childRatio = isMobile ? 1.6 : 2.5;
    final items = [
      _StatItemData('Present', '${stats.present}', AppColors.success, Icons.how_to_reg_rounded),
      _StatItemData('Absent', '${stats.absent}', AppColors.error, Icons.person_off_rounded),
      _StatItemData('Late Check-In', '${stats.lateCount}', AppColors.warning, Icons.warning_amber_rounded),
      _StatItemData('On Leave', '${stats.onLeave}', Colors.purple, Icons.time_to_leave_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: 96,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 0,
          color: item.color.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(color: item.color.withAlpha(51), width: 1.5),
          ),
          child: Center(
            child: ListTile(
              leading: Icon(item.icon, color: item.color, size: 28),
              title: Text(
                item.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
              ),
              subtitle: Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, ThemeData theme) {
    final dept = ref.watch(attendanceSearchDepartmentProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by employee name or ID...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(attendanceSearchNameQueryProvider.notifier).state = val;
                    },
                  ),
                ),
                const SizedBox(width: AppSizes.p12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dept,
                      items: ['All', 'Engineering', 'Human Resources', 'Sales', 'Marketing', 'Finance', 'Operations']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(attendanceSearchDepartmentProvider.notifier).state = val;
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, ThemeData theme, JoinedAttendanceRecord record) {
    Color statusColor = Colors.grey;
    final status = record.attendance.status.toLowerCase();
    if (status == 'present') statusColor = AppColors.success;
    if (status == 'absent') statusColor = AppColors.error;
    if (status == 'late') statusColor = AppColors.warning;
    if (status == 'half day') statusColor = Colors.orange;
    if (status == 'leave') statusColor = Colors.purple;

    final hasCheckedIn = record.attendance.checkInTime != null;
    final hasCheckedOut = record.attendance.checkOutTime != null;

    final inStr = hasCheckedIn ? DateFormat('hh:mm a').format(record.attendance.checkInTime!) : '--:--';
    final outStr = hasCheckedOut ? DateFormat('hh:mm a').format(record.attendance.checkOutTime!) : '--:--';

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
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withAlpha(26),
                        radius: 16,
                        child: Text(
                          record.employee.name.isNotEmpty ? record.employee.name[0].toUpperCase() : 'E',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        record.employee.name,
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
              Text(
                'ID: ${record.employee.employeeId} | ${record.employee.department}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.login, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('In: $inStr', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('Out: $outStr', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  if (record.attendance.workingHours > 0)
                    Text(
                      '${record.attendance.workingHours.toStringAsFixed(1)} hrs',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
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
            // Left icon placeholder
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withAlpha(26),
              child: Text(
                record.employee.name.isNotEmpty ? record.employee.name[0].toUpperCase() : 'E',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSizes.p16),

            // Middle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.employee.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ID: ${record.employee.employeeId} | ${record.employee.department}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.login, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('In: $inStr', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('Out: $outStr', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),

            // Right Status Badge
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

  // --- EMPLOYEE VIEW ---
  Widget _buildEmployeeView(BuildContext context, WidgetRef ref, ThemeData theme) {
    final todayAttendanceAsync = ref.watch(todayAttendanceStreamProvider);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppSizes.p24),
        child: todayAttendanceAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (attendance) {
            if (attendance == null) {
              return _buildEmptyState(theme, 'You have not checked in today.');
            }

            final checkInStr = attendance.checkInTime != null 
                ? DateFormat('hh:mm:ss a').format(attendance.checkInTime!) 
                : '--:--';
            final checkOutStr = attendance.checkOutTime != null 
                ? DateFormat('hh:mm:ss a').format(attendance.checkOutTime!) 
                : '--:--';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    side: BorderSide(color: theme.colorScheme.primary.withAlpha(51), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: Column(
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 64, color: AppColors.success),
                        const SizedBox(height: AppSizes.p16),
                        Text(
                          'Today\'s Record Locked',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSizes.p24),
                        
                        _buildTimeCardRow(theme, 'Date', DateFormat('yyyy-MM-dd').format(attendance.date)),
                        const Divider(),
                        _buildTimeCardRow(theme, 'Check-In Time', checkInStr),
                        const Divider(),
                        _buildTimeCardRow(theme, 'Check-Out Time', checkOutStr),
                        const Divider(),
                        _buildTimeCardRow(theme, 'Working Hours', '${attendance.workingHours.toStringAsFixed(2)} Hours'),
                        const Divider(),
                        _buildTimeCardRow(theme, 'Daily Status', attendance.status),
                        if (attendance.remarks != null) ...[
                          const Divider(),
                          _buildTimeCardRow(theme, 'Remarks', attendance.remarks!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeCardRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSizes.p16),
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItemData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  _StatItemData(this.label, this.value, this.color, this.icon);
}
