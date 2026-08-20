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
import '../providers/leaves_provider.dart';

class LeaveDashboardScreen extends ConsumerWidget {
  const LeaveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(leaveStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final isEmployee = role == 'Employee';
    final isSupervisor = role == 'Supervisor';
    final isManager = role == 'Owner' || role == 'HR';
    final companyName = authState.selectedCompany ?? 'Apex Industries';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(isEmployee ? '$companyName - My Leaves' : '$companyName - Leave Admin'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading dashboard: $err')),
        data: (stats) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome & Header Card
                      _buildHeaderCard(context, theme, role, isEmployee, isDark),
                      const SizedBox(height: AppSizes.p24),

                      // Stats Grid
                      Text(
                        isEmployee ? 'My Leave Overview' : 'Leave Analytics Overview',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildStatsGrid(context, stats, isEmployee),
                      const SizedBox(height: AppSizes.p32),

                      // Quick Actions Grid
                      Text(
                        'Operations',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildActionsGrid(context, isEmployee, isSupervisor, isManager),
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

  Widget _buildHeaderCard(
    BuildContext context,
    ThemeData theme,
    String role,
    bool isEmployee,
    bool isDark,
  ) {
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
                    'LEAVE MANAGEMENT MODULE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  isEmployee ? 'Leave Application Portal' : 'Staff Leaves Dashboard',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  isEmployee
                      ? 'Apply for sick, casual, earned leaves, request work from home plan, and monitor approvals.'
                      : 'Review staff leaves, approve pending requests, view leave calendar, and manage balances.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p16),
          Icon(
            Icons.time_to_leave_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, LeaveStats stats, bool isEmployee) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 5;

    final cards = [
      _StatItem('Total Requests', stats.totalRequests.toString(), Icons.playlist_add_check_rounded, AppColors.info),
      _StatItem('Pending', stats.pending.toString(), Icons.pending_actions_rounded, AppColors.warning),
      _StatItem('Approved', stats.approved.toString(), Icons.verified_rounded, AppColors.success),
      _StatItem('Rejected', stats.rejected.toString(), Icons.cancel_outlined, AppColors.error),
      _StatItem(
        isEmployee ? 'On Leave Today' : 'Employees On Leave',
        stats.onLeaveToday.toString(),
        Icons.beach_access_rounded,
        Colors.purple,
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
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return CustomCard(
          title: card.value,
          subtitle: card.label,
          icon: card.icon,
          iconColor: card.color,
          onTap: () {
            if (isEmployee) {
              context.push('/leaves/history');
            } else {
              context.push('/leaves/requests?status=${card.label}');
            }
          },
        );
      },
    );
  }

  Widget _buildActionsGrid(
    BuildContext context,
    bool isEmployee,
    bool isSupervisor,
    bool isManager,
  ) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 3;

    final actions = [
      _ActionItem(
        'Apply Leave',
        'Request time off or work from home schedule',
        Icons.add_moderator_rounded,
        Colors.teal,
        () => context.push('/leaves/apply'),
      ),
      _ActionItem(
        'My Leave History',
        'View history of leave request statements',
        Icons.history_rounded,
        Colors.indigo,
        () => context.push('/leaves/history'),
      ),
      if (isSupervisor || isManager) ...[
        _ActionItem(
          'Pending Approvals',
          'Review and approve pending department leaves',
          Icons.fact_check_rounded,
          Colors.amber,
          () => context.push('/leaves/approval'),
        ),
        _ActionItem(
          'Company Directory',
          'View all staff leave requests directory',
          Icons.folder_shared_rounded,
          Colors.blueGrey,
          () => context.push('/leaves/requests'),
        ),
      ],
      _ActionItem(
        'Leave Calendar',
        'Check who is on leave on calendar schedule',
        Icons.calendar_month_rounded,
        Colors.purple,
        () => context.push('/leaves/calendar'),
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
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final act = actions[index];
        return CustomCard(
          title: act.title,
          subtitle: act.description,
          icon: act.icon,
          iconColor: act.color,
          onTap: act.onTap,
        );
      },
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}

class _ActionItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionItem(this.title, this.description, this.icon, this.color, this.onTap);
}
