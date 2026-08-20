import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../providers/attendance_provider.dart';

class SearchAttendanceScreen extends ConsumerWidget {
  const SearchAttendanceScreen({super.key});

  Future<void> _selectDate(BuildContext context, WidgetRef ref, DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(attendanceSearchDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchResultsAsync = ref.watch(searchedAttendanceProvider);
    final targetDate = ref.watch(attendanceSearchDateProvider);
    final selectedDept = ref.watch(attendanceSearchDepartmentProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Search Employee Attendance'),
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
                          'Search & Filters',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSizes.p12),

                        // Text Search
                        TextField(
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
                        const SizedBox(height: AppSizes.p12),

                        ResponsiveFormRow(
                          children: [
                            // Department Filter
                            DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: selectedDept,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                prefixIcon: const Icon(Icons.business_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: ['All', 'Engineering', 'Human Resources', 'Sales', 'Marketing', 'Finance', 'Operations']
                                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(attendanceSearchDepartmentProvider.notifier).state = val;
                                }
                              },
                            ),

                            // Date Filter
                            InkWell(
                              onTap: () => _selectDate(context, ref, targetDate),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Search Date',
                                  prefixIcon: const Icon(Icons.date_range_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                child: Text(
                                  DateFormat('yyyy-MM-dd').format(targetDate),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p24),

                // Results Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Search Results',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    searchResultsAsync.when(
                      data: (list) => Text(
                        'Found: ${list.length}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                      loading: () => const SizedBox(),
                      error: (e, _) => const SizedBox(),
                    )
                  ],
                ),
                const SizedBox(height: AppSizes.p12),

                // Search Results list
                searchResultsAsync.when(
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
                        return _buildSearchResultCard(context, theme, rec);
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

  Widget _buildSearchResultCard(BuildContext context, ThemeData theme, JoinedAttendanceRecord record) {
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
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          onTap: () {
            context.push('/attendance/employee/${record.employee.employeeId}');
          },
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
                  'ID: ${record.employee.employeeId} | ${record.employee.department} | ${record.employee.designation}',
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
                        Text('In: $inTime', style: theme.textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Out: $outTime', style: theme.textTheme.bodySmall),
                      ],
                    ),
                    Row(
                      children: [
                        if (record.attendance.workingHours > 0) ...[
                          Text(
                            '${record.attendance.workingHours.toStringAsFixed(1)} hrs',
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
                if (record.attendance.remarks != null && record.attendance.remarks != 'No record found') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Remarks: ${record.attendance.remarks}',
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                  ),
                ]
              ],
            ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        onTap: () {
          // Open detail timesheet audit screen for this specific employee
          context.push('/attendance/employee/${record.employee.employeeId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withAlpha(26),
                child: Text(
                  record.employee.name.isNotEmpty ? record.employee.name[0].toUpperCase() : 'E',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSizes.p16),

              // Timings & employee info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employee.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ID: ${record.employee.employeeId} | ${record.employee.department} | ${record.employee.designation}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.login, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('In: $inTime', style: theme.textTheme.bodySmall),
                        const SizedBox(width: 16),
                        Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Out: $outTime', style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (record.attendance.remarks != null && record.attendance.remarks != 'No record found') ...[
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
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                ],
              ),
            ],
          ),
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
            Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No employees match your search criteria.',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
