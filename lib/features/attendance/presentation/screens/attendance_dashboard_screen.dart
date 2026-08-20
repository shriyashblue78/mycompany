import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/attendance_provider.dart';

class AttendanceDashboardScreen extends ConsumerWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final company = authState.selectedCompany ?? 'Apex Industries';
    
    final isStaff = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Attendance Audits' : 'My Attendance'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role-based Header Card
                  _buildHeaderCard(theme, authState.userName ?? 'User', role, company),
                  const SizedBox(height: AppSizes.p24),

                  if (isStaff) ...[
                    // Workforce Today Summary (HR / Owner View)
                    Text(
                      "Today's Workforce Overview",
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildStaffStatsGrid(context, ref),
                    const SizedBox(height: AppSizes.p32),

                    // Admin operations
                    Text(
                      'Attendance Operations',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildStaffModules(context),
                  ] else ...[
                    // Today's Check In/Out Status (Employee View)
                    Text(
                      "Today's Punch Status",
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildEmployeeTodayStatus(context, ref, theme, isDark),
                    const SizedBox(height: AppSizes.p32),

                    // Employee portal links
                    Text(
                      'Attendance Log & Summary',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildEmployeeModules(context, authState.user?.employeeId ?? ''),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, String userName, String role, String company) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p28, vertical: AppSizes.p24),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  'Welcome, $userName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  'Company: $company',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p16),
          Icon(
            Icons.fingerprint_rounded,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffStatsGrid(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todayAttendanceStatsProvider);

    final columns = ResponsiveLayout.isMobile(context)
        ? 2
        : ResponsiveLayout.isTablet(context)
            ? 3
            : 5;

    return statsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error loading stats: $err', style: const TextStyle(color: AppColors.error))),
      data: (stats) {
        final statItems = [
          _StatItem('Total Staff', '${stats.totalEmployees}', Icons.people, Colors.blue),
          _StatItem('Present Today', '${stats.present}', Icons.check_circle_rounded, AppColors.success),
          _StatItem('Absent Today', '${stats.absent}', Icons.cancel_rounded, AppColors.error),
          _StatItem('Late Today', '${stats.lateCount}', Icons.warning_rounded, AppColors.warning),
          _StatItem('On Leave', '${stats.onLeave}', Icons.time_to_leave_rounded, Colors.purple),
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
          itemCount: statItems.length,
          itemBuilder: (context, index) {
            final item = statItems[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
                child: Row(
                  children: [
                    Icon(item.icon, color: item.color, size: 30),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.value,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            maxLines: 1,
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
      },
    );
  }

  Widget _buildStaffModules(BuildContext context) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 3;

    final modules = [
      _ModuleData(
        "Today's Attendance",
        "View who is present, late, or absent today in real-time.",
        Icons.today_rounded,
        AppColors.success,
        '/attendance/today',
      ),
      _ModuleData(
        "Search Attendance",
        "Find employee timesheets by name, ID, department, or date.",
        Icons.search_rounded,
        Colors.blue,
        '/attendance/search',
      ),
      _ModuleData(
        "Attendance History",
        "Browse past attendance records with custom filters.",
        Icons.history_rounded,
        Colors.indigo,
        '/attendance/history',
      ),
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
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final mod = modules[index];
        return CustomCard(
          title: mod.title,
          subtitle: mod.description,
          icon: mod.icon,
          iconColor: mod.color,
          onTap: () => context.push(mod.route),
        );
      },
    );
  }

  Widget _buildEmployeeTodayStatus(BuildContext context, WidgetRef ref, ThemeData theme, bool isDark) {
    final todayAttendanceAsync = ref.watch(todayAttendanceStreamProvider);

    return todayAttendanceAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
      data: (attendance) {
        final bool isCheckedIn = attendance != null;
        final bool isCheckedOut = attendance?.checkOutTime != null;

        String statusText = 'Not Checked In';
        Color statusColor = AppColors.error;
        IconData statusIcon = Icons.exit_to_app_rounded;

        if (isCheckedIn && !isCheckedOut) {
          statusText = 'Checked In';
          statusColor = AppColors.success;
          statusIcon = Icons.login_rounded;
        } else if (isCheckedOut) {
          statusText = 'Checked Out (${attendance!.workingHours.toStringAsFixed(1)} hrs)';
          statusColor = Colors.blue;
          statusIcon = Icons.offline_pin_rounded;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.p20),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: theme.colorScheme.outline.withAlpha(51)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.p12),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 28),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (isCheckedIn) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Check-in: ${_formatTime(attendance.checkInTime)}${isCheckedOut ? ' | Check-out: ${_formatTime(attendance.checkOutTime)}' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'You have not marked your attendance today.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: isCheckedOut ? Colors.grey : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                onPressed: isCheckedOut
                    ? null
                    : () {
                        context.push('/attendance/mark');
                      },
                icon: const Icon(Icons.fingerprint),
                label: Text(isCheckedIn ? 'Punch Check-Out' : 'Punch Check-In'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeModules(BuildContext context, String employeeId) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 3;

    final modules = [
      _ModuleData(
        "Today's Time Card",
        "View details of today's check-in/out and remarks.",
        Icons.calendar_view_day_rounded,
        AppColors.success,
        '/attendance/today',
      ),
      _ModuleData(
        "My Monthly Logs",
        "Check working hours and attendance percentage for this month.",
        Icons.calendar_month_rounded,
        Colors.blue,
        '/attendance/monthly',
      ),
      _ModuleData(
        "History Logs",
        "Search and browse your past attendance calendar sheets.",
        Icons.history_toggle_off_rounded,
        Colors.indigo,
        '/attendance/history',
      ),
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
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final mod = modules[index];
        return CustomCard(
          title: mod.title,
          subtitle: mod.description,
          icon: mod.icon,
          iconColor: mod.color,
          onTap: () {
            if (mod.title == "My Monthly Logs") {
              // Direct employee to details screen of their own records
              context.push('/attendance/monthly');
            } else {
              context.push(mod.route);
            }
          },
        );
      },
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hr = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hr:$min';
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}

class _ModuleData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  _ModuleData(this.title, this.description, this.icon, this.color, this.route);
}
