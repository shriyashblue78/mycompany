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
import '../../../employee/domain/models/employee_model.dart';
import '../../domain/models/task_model.dart';
import '../providers/tasks_provider.dart';

class TaskCompletedScreen extends ConsumerWidget {
  const TaskCompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(companyTasksStreamProvider);
    final employeesAsync = ref.watch(companyEmployeesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    final role = user.role;
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Completed Deliverables'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading completed tasks: $err')),
        data: (tasks) {
          // Filter tasks based on status == 'Completed' and role restrictions
          final completedTasks = tasks.where((t) {
            final isCompleted = t.status == 'Completed';
            if (isManager) {
              return isCompleted;
            } else {
              return isCompleted && t.assignedToEmployeeId == user.employeeId;
            }
          }).toList();

          if (completedTasks.isEmpty) {
            return _buildEmptyState(context, isManager);
          }

          return employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading employee directory: $err')),
            data: (employees) {
              final isMobile = ResponsiveLayout.isMobile(context);
              final isTablet = ResponsiveLayout.isTablet(context);
              final columns = isMobile ? 1 : (isTablet ? 2 : 3);

              if (isMobile) {
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: ListView.builder(
                      itemCount: completedTasks.length,
                      itemBuilder: (context, index) {
                        final task = completedTasks[index];
                        final assignee = employees.where((e) => e.employeeId == task.assignedToEmployeeId).firstOrNull;
                        final assigneeName = assignee != null ? assignee.name : 'Staff (${task.assignedToEmployeeId})';

                        return _buildCompletedTaskTile(context, theme, task, assigneeName, isDark, isManager);
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
                    itemCount: completedTasks.length,
                    itemBuilder: (context, index) {
                      final task = completedTasks[index];
                      final assignee = employees.where((e) => e.employeeId == task.assignedToEmployeeId).firstOrNull;
                      final assigneeName = assignee != null ? assignee.name : 'Staff (${task.assignedToEmployeeId})';

                      return _buildCompletedTaskTile(context, theme, task, assigneeName, isDark, isManager);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isManager) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No Completed Tasks',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              isManager
                  ? 'No tasks have been marked as Completed yet in the company database.'
                  : 'You have not completed any tasks yet. Finish active assignments to add them here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTaskTile(
    BuildContext context,
    ThemeData theme,
    TaskModel task,
    String assigneeName,
    bool isDark,
    bool isManager,
  ) {
    final completedDateStr = task.completedDate != null
        ? '${task.completedDate!.year}-${task.completedDate!.month.toString().padLeft(2, '0')}-${task.completedDate!.day.toString().padLeft(2, '0')}'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? theme.colorScheme.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(
            color: AppColors.success.withAlpha(isDark ? 80 : 40),
            width: 1.5,
          ),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    // Completed Status Stamp
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
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
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                ),
                const SizedBox(height: AppSizes.p16),

                // Bottom row details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Assignee
                    Text(
                      isManager ? 'Assignee: $assigneeName' : 'Dept: ${task.department}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),

                    // Completed Date
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Finished On: $completedDateStr',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
