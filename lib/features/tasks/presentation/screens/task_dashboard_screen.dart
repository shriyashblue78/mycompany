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
import '../providers/tasks_provider.dart';

class TaskDashboardScreen extends ConsumerWidget {
  const TaskDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(taskStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';
    final companyName = authState.selectedCompany ?? 'Apex Industries';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(isManager ? '$companyName - Tasks Admin' : '$companyName - My Tasks'),
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
                      // Header Card
                      _buildHeaderCard(context, theme, role, isManager, isDark),
                      const SizedBox(height: AppSizes.p24),

                      // Stats Grid
                      Text(
                        isManager ? 'Company Task Analytics' : 'My Personal Task Analytics',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildStatsGrid(context, stats),
                      const SizedBox(height: AppSizes.p32),

                      // Quick Actions / Shortcuts
                      Text(
                        'Actions',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildActionsGrid(context, isManager),
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
    bool isManager,
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
                    'TASK MANAGEMENT MODULE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  isManager ? 'Enterprise Tasks Console' : 'My Work Deliverables',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  isManager
                      ? 'Create tasks, assign jobs to employees, monitor progress real-time, and update statuses.'
                      : 'View assignments, check job specs, update progress and report deliverables.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p16),
          Icon(
            Icons.assignment_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, TaskStats stats) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 5;

    final cards = [
      _StatItem('Total Tasks', stats.total.toString(), Icons.playlist_add_check_rounded, AppColors.info),
      _StatItem('Pending', stats.pending.toString(), Icons.hourglass_empty_rounded, Colors.blueGrey),
      _StatItem('In Progress', stats.inProgress.toString(), Icons.trending_up_rounded, AppColors.warning),
      _StatItem('Completed', stats.completed.toString(), Icons.check_circle_outline_rounded, AppColors.success),
      _StatItem('Overdue', stats.overdue.toString(), Icons.warning_amber_rounded, AppColors.error),
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
            // Filter by selected status in the tasks list
            if (card.label == 'Total Tasks') {
              context.push('/tasks/list');
            } else {
              context.push('/tasks/list?status=${card.label}');
            }
          },
        );
      },
    );
  }

  Widget _buildActionsGrid(BuildContext context, bool isManager) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 3;

    final actions = [
      if (isManager) ...[
        _ActionItem(
          'Create Task',
          'Create and delegate a new task to staff',
          Icons.add_task_rounded,
          Colors.teal,
          () => context.push('/tasks/create'),
        ),
        _ActionItem(
          'All Task Directory',
          'View and search all tasks in the company',
          Icons.list_alt_rounded,
          Colors.indigo,
          () => context.push('/tasks/list'),
        ),
      ] else ...[
        _ActionItem(
          'My Active Tasks',
          'View and update your active assignments',
          Icons.checklist_rtl_rounded,
          Colors.indigo,
          () => context.push('/tasks/my-tasks'),
        ),
      ],
      _ActionItem(
        'Completed Archive',
        'View recently completed deliverables',
        Icons.verified_rounded,
        Colors.green,
        () => context.push('/tasks/completed'),
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
