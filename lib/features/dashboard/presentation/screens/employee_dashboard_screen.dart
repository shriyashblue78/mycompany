import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final userName = authState.userName ?? 'Employee';
    final company = authState.selectedCompany ?? 'Apex Industries';
    final employeeId = authState.user?.employeeId ?? '';

    // Debug print tasks
    try {
      ref.watch(companyTasksStreamProvider).whenData((tasks) {
        for (final t in tasks) {
          debugPrint("DEBUG TASK: id=${t.taskId} title=${t.title} status=${t.status} startTime=${t.taskStartTime} deadline=${t.deadlineTime} dueDate=${t.dueDate} actualComp=${t.actualCompletionTime} timing=${t.completionTiming} timeTaken=${t.totalTimeTakenMinutes} lateMin=${t.lateDurationMinutes} score=${t.performanceScore} rating=${t.performanceRating}");
        }
      });
    } catch (e) {
      debugPrint("Error watching tasks for debug: $e");
    }

    if (isMobile) {
      return _MobileEmployeeDashboard(
        ref: ref,
        userName: userName,
        company: company,
        isDark: isDark,
        theme: theme,
        employeeId: employeeId,
        logoUrl: authState.companyLogoUrl,
      );
    }

    // ── Desktop/Tablet layout (unchanged) ──────────────────────────────────
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(company),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: const [
          NotificationBell(),
        ],
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
                  _buildCompanyLogoHeader(context, authState.companyLogoUrl, company, theme),
                  const SizedBox(height: AppSizes.p16),
                  _buildWelcomeCard(theme, userName, company, isDark),
                  const SizedBox(height: AppSizes.p24),
                  Text(
                    'My Status Overview',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSizes.p12),
                  _buildEmployeeStats(context, ref),
                  const SizedBox(height: AppSizes.p32),
                  Text(
                    'Employee Portal Features',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSizes.p12),
                  _buildEmployeeModules(context, employeeId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyLogoHeader(BuildContext context, String? logoUrl, String companyName, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildLogoPlaceholder(companyName, theme),
              ),
            )
          else
            _buildLogoPlaceholder(companyName, theme),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here's what's happening in your company today.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder(String companyName, ThemeData theme) {
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, String userName, String company, bool isDark) {
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
                    'EMPLOYEE PORTAL',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  'Hello, $userName!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  'Punch in/out, check your assignments, and file leave requests.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p16),
          Icon(
            Icons.person_outline_rounded,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeStats(BuildContext context, WidgetRef ref) {
    final taskStats = ref.watch(taskStatsProvider);
    final taskProgressText = taskStats.maybeWhen(
      data: (stats) => '${stats.completed} of ${stats.total} Completed',
      orElse: () => 'Loading...',
    );
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 3;
    final stats = [
      _EmpStatData('Punch Status', 'Checked In at 9:02 AM', Icons.fingerprint_rounded),
      _EmpStatData('My Today Tasks', taskProgressText, Icons.check_circle_outline),
      _EmpStatData('Leave Balances', '12 Days Left', Icons.time_to_leave_outlined),
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
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return CustomCard(
          title: stat.value,
          subtitle: stat.label,
          icon: stat.icon,
          onTap: () {
            if (stat.label == 'Punch Status') {
              context.push('/attendance');
            } else if (stat.label == 'My Today Tasks') {
              context.push('/tasks/my-tasks');
            } else if (stat.label == 'Leave Balances') {
              context.push('/leaves');
            }
          },
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
      _EmpModuleData('Punch Attendance', 'Check-in or check-out of work with geo-location validation', Icons.fingerprint_rounded),
      _EmpModuleData('My Tasks Board', 'View assignments, check details, and update status logs', Icons.checklist_rounded),
      _EmpModuleData('Apply Leave Plan', 'Request sick, annual, or medical leaves and check statuses', Icons.time_to_leave_outlined),
      _EmpModuleData('Notifications Feed', 'Read manager broadcasts and leave decision details', Icons.notifications_active_outlined),
      _EmpModuleData('My Profile Details', 'View payroll specifications, bank accounts, and edit details', Icons.account_box_outlined),
      _EmpModuleData('Assigned Production', 'View target and status logs for your assigned production', Icons.precision_manufacturing_outlined),
      _EmpModuleData('My Performance', 'View your performance scores, timing history, and ratings', Icons.assessment_rounded),
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
          onTap: () {
            if (mod.title == 'Punch Attendance') context.push('/attendance');
            else if (mod.title == 'My Tasks Board') context.push('/tasks/my-tasks');
            else if (mod.title == 'Apply Leave Plan') context.push('/leaves');
            else if (mod.title == 'Assigned Production') context.push('/production');
            else if (mod.title == 'My Performance') context.push('/employees/$employeeId/performance');
          },
        );
      },
    );
  }
}

// ─── Mobile-specific Employee Dashboard ──────────────────────────────────────
class _MobileEmployeeDashboard extends ConsumerWidget {
  final WidgetRef ref;
  final String userName;
  final String company;
  final bool isDark;
  final ThemeData theme;
  final String employeeId;
  final String? logoUrl;

  const _MobileEmployeeDashboard({
    required this.ref,
    required this.userName,
    required this.company,
    required this.isDark,
    required this.theme,
    required this.employeeId,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStats = ref.watch(taskStatsProvider);
    final taskProgressText = taskStats.maybeWhen(
      data: (stats) => '${stats.completed}/${stats.total}',
      orElse: () => '—',
    );

    final modules = [
      _MobileModule('Punch Attendance', 'Check in or out of work', Icons.fingerprint_rounded, AppColors.primaryLight, '/attendance'),
      _MobileModule('My Tasks Board', 'View and update assignments', Icons.checklist_rounded, Colors.indigo, '/tasks/my-tasks'),
      _MobileModule('Apply Leave Plan', 'Request time off', Icons.time_to_leave_outlined, Colors.orange, '/leaves'),
      _MobileModule('Notifications', 'Manager broadcasts & updates', Icons.notifications_active_outlined, Colors.teal, '/notifications'),
      _MobileModule('My Profile', 'Payroll and account details', Icons.account_box_outlined, Colors.purple, '/settings'),
      _MobileModule('Assigned Production', 'Your production targets', Icons.precision_manufacturing_outlined, Colors.green, '/production'),
      _MobileModule('My Performance', 'View your score history', Icons.assessment_rounded, Colors.teal, '/employees/$employeeId/performance'),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          company,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: const [
          NotificationBell(),
        ],
      ),
      drawer: const ERPDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildCompanyLogoHeader(context, logoUrl, company, theme),
          const SizedBox(height: 16),
          // Hero Card
          MobileHeroCard(
            label: 'Employee Portal',
            title: 'Hello, $userName!',
            subtitle: 'Punch in/out, tasks, and leave requests.',
            backgroundColor:
                isDark ? theme.colorScheme.surface : AppColors.primaryLight,
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 20),

          // Status Overview — horizontal scroll row
          Text('My Status', style: MobileText.sectionStyle(context)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 110,
            children: [
              MobileStatCard(
                label: 'Punch Status',
                value: 'In',
                icon: Icons.fingerprint_rounded,
                color: AppColors.success,
                width: double.infinity,
                onTap: () => context.push('/attendance'),
              ),
              MobileStatCard(
                label: 'Tasks Today',
                value: taskProgressText,
                icon: Icons.check_circle_outline,
                color: Colors.indigo,
                width: double.infinity,
                onTap: () => context.push('/tasks/my-tasks'),
              ),
              MobileStatCard(
                label: 'Leave Days',
                value: '12',
                icon: Icons.time_to_leave_outlined,
                color: Colors.orange,
                width: double.infinity,
                onTap: () => context.push('/leaves'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Feature Modules — 2-column grid
          Text('Quick Access', style: MobileText.sectionStyle(context)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 72,
            children: modules.map((m) {
              return InkWell(
                onTap: () => context.push(m.route),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: m.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: m.color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: m.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m.icon, color: m.color, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyLogoHeader(BuildContext context, String? logoUrl, String companyName, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildLogoPlaceholder(companyName, theme),
              ),
            )
          else
            _buildLogoPlaceholder(companyName, theme),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here's what's happening in your company today.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder(String companyName, ThemeData theme) {
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _EmpStatData {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  _EmpStatData(this.label, this.value, this.icon, [this.color]);
}

class _EmpModuleData {
  final String title;
  final String description;
  final IconData icon;
  final Color? color;
  _EmpModuleData(this.title, this.description, this.icon, [this.color]);
}

class _MobileModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  const _MobileModule(this.title, this.subtitle, this.icon, this.color, this.route);
}
