import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/task_model.dart';
import '../providers/tasks_provider.dart';

class TaskMyTasksScreen extends ConsumerWidget {
  const TaskMyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(companyTasksStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('My Active Tasks'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading my tasks: $err')),
        data: (tasks) {
          // Filter to show ONLY tasks assigned to this employee and NOT completed or cancelled
          final myActiveTasks = tasks.where((t) {
            final matchesUser = t.assignedToEmployeeId == user.employeeId;
            final isNotFinished = t.status != 'Completed' && t.status != 'Cancelled';
            return matchesUser && isNotFinished;
          }).toList();

          if (myActiveTasks.isEmpty) {
            return _buildEmptyState(context);
          }

          final isMobile = ResponsiveLayout.isMobile(context);
          final isTablet = ResponsiveLayout.isTablet(context);
          final columns = isMobile ? 1 : (isTablet ? 2 : 3);

          if (isMobile) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                padding: const EdgeInsets.all(AppSizes.p24),
                child: ListView.builder(
                  itemCount: myActiveTasks.length,
                  itemBuilder: (context, index) {
                    final task = myActiveTasks[index];
                    return _buildTaskTile(context, theme, task, isDark);
                  },
                ),
              ),
            );
          }

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              padding: const EdgeInsets.all(AppSizes.p24),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSizes.p16,
                  mainAxisSpacing: AppSizes.p16,
                  mainAxisExtent: 180,
                ),
                itemCount: myActiveTasks.length,
                itemBuilder: (context, index) {
                  final task = myActiveTasks[index];
                  return _buildTaskTile(context, theme, task, isDark);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_add_check_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'All Caught Up!',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              'You have no pending or active tasks assigned to you.\nCheck the completed archive to review your past jobs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSizes.p24),
            ElevatedButton.icon(
              onPressed: () => context.push('/tasks/completed'),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('View Completed Archive'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, ThemeData theme, TaskModel task, bool isDark) {
    final statusColor = _getStatusColor(task.status);
    final priorityColor = _getPriorityColor(task.priority);
    final dueStr = '${task.dueDate.year}-${task.dueDate.month.toString().padLeft(2, '0')}-${task.dueDate.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? theme.colorScheme.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: isDark ? BorderSide(color: Colors.white.withAlpha(15), width: 1) : BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: InkWell(
          onTap: () => context.push('/tasks/${task.taskId}'),
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Expanded(
                      child: Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Priority Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.priority,
                        style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: AppSizes.p16),

                // Bottom line: progress, dates, and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Progress percentage
                    Row(
                      children: [
                        Text(
                          'Progress: ',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                        Text(
                          '${task.progress.toInt()}%',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),

                    // Due Date
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Due: $dueStr',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress / 100,
                    minHeight: 4,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return AppColors.error;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return AppColors.warning;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'In Progress':
        return AppColors.info;
      case 'On Hold':
        return Colors.purple;
      case 'Cancelled':
        return Colors.grey.shade600;
      default:
        return AppColors.warning;
    }
  }
}
