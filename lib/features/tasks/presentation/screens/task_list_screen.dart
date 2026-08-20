import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../domain/models/task_model.dart';
import '../providers/tasks_provider.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const TaskListScreen({super.key, this.initialStatus});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialStatus != null) {
        ref.read(taskStatusFilterProvider.notifier).state = widget.initialStatus;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(filteredTasksProvider);
    final employeesAsync = ref.watch(companyEmployeesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Tasks Directory'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (isManager)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.p16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/tasks/create'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Task'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: const ERPDrawer(),
      body: Column(
        children: [
          // Filter Panel
          _buildFilterPanel(context, isManager),

          // Task List Results
          Expanded(
            child: tasksAsync.when(
              loading: () => const CardListSkeleton(),
              error: (err, stack) => Center(child: Text('Error loading tasks: $err')),
              data: (tasks) {
                if (tasks.isEmpty) {
                  final hasFilters = ref.read(taskSearchQueryProvider).isNotEmpty ||
                      ref.read(taskDepartmentFilterProvider) != null ||
                      ref.read(taskPriorityFilterProvider) != null ||
                      ref.read(taskStatusFilterProvider) != null ||
                      ref.read(taskEmployeeFilterProvider) != null ||
                      ref.read(taskDueDateFilterProvider) != null;
                  return EmptyStateWidget(
                    icon: hasFilters ? Icons.search_off_rounded : Icons.playlist_remove_rounded,
                    title: hasFilters ? 'No Matching Tasks' : 'No Tasks Assigned Yet',
                    description: hasFilters
                        ? 'Try relaxing your filter parameters to view other tasks.'
                        : 'Assign tasks to employees to see them in this database.',
                    ctaLabel: isManager ? 'Create Task' : null,
                    onCtaPressed: isManager ? () => context.push('/tasks/create') : null,
                  );
                }

                return employeesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading assignee info: $err')),
                  data: (employees) {
                    return _buildResponsiveList(context, tasks, employees);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(BuildContext context, bool isManager) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    final searchQuery = ref.watch(taskSearchQueryProvider);
    final selectedDept = ref.watch(taskDepartmentFilterProvider);
    final selectedPriority = ref.watch(taskPriorityFilterProvider);
    final selectedStatus = ref.watch(taskStatusFilterProvider);
    final selectedEmployee = ref.watch(taskEmployeeFilterProvider);
    final selectedDueDate = ref.watch(taskDueDateFilterProvider);

    final employeesAsync = ref.watch(companyEmployeesProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      color: theme.colorScheme.surface,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search tasks by title, details or department...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            ref.read(taskSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) {
                  ref.read(taskSearchQueryProvider.notifier).state = val;
                },
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: searchQuery,
                    selection: TextSelection.collapsed(offset: searchQuery.length),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),

              // Filter Dropdowns Row
              Wrap(
                spacing: AppSizes.p8,
                runSpacing: AppSizes.p8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Department Dropdown
                  _buildDropdown(
                    label: 'Department',
                    value: selectedDept,
                    items: ['All', ...kDepartments],
                    onChanged: (val) {
                      ref.read(taskDepartmentFilterProvider.notifier).state = val == 'All' ? null : val;
                    },
                  ),

                  // Priority Dropdown
                  _buildDropdown(
                    label: 'Priority',
                    value: selectedPriority,
                    items: ['All', ...kTaskPriorities],
                    onChanged: (val) {
                      ref.read(taskPriorityFilterProvider.notifier).state = val == 'All' ? null : val;
                    },
                  ),

                  // Status Dropdown
                  _buildDropdown(
                    label: 'Status',
                    value: selectedStatus,
                    items: ['All', ...kTaskStatuses],
                    onChanged: (val) {
                      ref.read(taskStatusFilterProvider.notifier).state = val == 'All' ? null : val;
                    },
                  ),

                  // Employee Dropdown (Managers only)
                  if (isManager)
                    employeesAsync.maybeWhen(
                      data: (list) {
                        final items = {
                          'All': 'All Staff',
                          for (var e in list) e.employeeId: e.name,
                        };
                        return _buildCustomDropdown(
                          label: 'Assigned To',
                          value: selectedEmployee ?? 'All',
                          items: items,
                          onChanged: (val) {
                            ref.read(taskEmployeeFilterProvider.notifier).state = val == 'All' ? null : val;
                          },
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),

                  // Due Date Filter Button
                  TextButton.icon(
                    onPressed: () async {
                      if (selectedDueDate != null) {
                        ref.read(taskDueDateFilterProvider.notifier).state = null;
                        return;
                      }
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        ref.read(taskDueDateFilterProvider.notifier).state = date;
                      }
                    },
                    icon: Icon(
                      selectedDueDate != null ? Icons.calendar_today_rounded : Icons.calendar_month_rounded,
                      size: 18,
                    ),
                    label: Text(
                      selectedDueDate != null
                          ? 'Due: ${selectedDueDate.year}-${selectedDueDate.month.toString().padLeft(2, '0')}-${selectedDueDate.day.toString().padLeft(2, '0')} (Clear)'
                          : 'Filter By Due Date',
                    ),
                  ),

                  // Reset Filters Button
                  if (searchQuery.isNotEmpty ||
                      selectedDept != null ||
                      selectedPriority != null ||
                      selectedStatus != null ||
                      selectedEmployee != null ||
                      selectedDueDate != null)
                    TextButton(
                      onPressed: () {
                        ref.read(taskSearchQueryProvider.notifier).state = '';
                        ref.read(taskDepartmentFilterProvider.notifier).state = null;
                        ref.read(taskPriorityFilterProvider.notifier).state = null;
                        ref.read(taskStatusFilterProvider.notifier).state = null;
                        ref.read(taskEmployeeFilterProvider.notifier).state = null;
                        ref.read(taskDueDateFilterProvider.notifier).state = null;
                      },
                      child: const Text(
                        'Reset Filters',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? 'All',
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text('$label: $item', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: items.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text('$label: ${entry.value}', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = ref.watch(taskSearchQueryProvider).isNotEmpty ||
        ref.watch(taskDepartmentFilterProvider) != null ||
        ref.watch(taskPriorityFilterProvider) != null ||
        ref.watch(taskStatusFilterProvider) != null ||
        ref.watch(taskEmployeeFilterProvider) != null ||
        ref.watch(taskDueDateFilterProvider) != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.playlist_remove_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              hasFilters ? 'No Matching Tasks' : 'No Tasks Assigned Yet',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              hasFilters
                  ? 'Try relaxing your filter parameters to view other tasks.'
                  : 'Assign tasks to employees to see them in this database.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveList(
    BuildContext context,
    List<TaskModel> tasks,
    List<EmployeeModel> employees,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final task = tasks[i];
          final assigneeName = _getAssigneeName(employees, task.assignedToEmployeeId);
          final dueStr = '${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}';
          return MobileListTile(
            title: task.title,
            subtitle: 'Assigned to: $assigneeName',
            meta: 'Due: $dueStr · ${task.priority} priority',
            leadingIcon: Icons.task_rounded,
            leadingColor: _getPriorityColor(task.priority),
            statusLabel: task.status,
            statusColor: _getStatusColor(task.status),
            onTap: () => context.push('/tasks/${task.taskId}'),
          );
        },
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        padding: const EdgeInsets.all(AppSizes.p16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSizes.p16,
            mainAxisSpacing: AppSizes.p16,
            mainAxisExtent: 180,
          ),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final assigneeName = _getAssigneeName(employees, task.assignedToEmployeeId);
            return _buildTaskCard(context, task, assigneeName);
          },
        ),
      ),
    );
  }

  String _getAssigneeName(List<EmployeeModel> list, String employeeId) {
    final emp = list.where((e) => e.employeeId == employeeId);
    if (emp.isNotEmpty) {
      return emp.first.name;
    }
    return 'Unknown ($employeeId)';
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task, String assigneeName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final priorityColor = _getPriorityColor(task.priority);
    final statusColor = _getStatusColor(task.status);

    final dueStr = '${task.dueDate.year}-${task.dueDate.month.toString().padLeft(2, '0')}-${task.dueDate.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? theme.colorScheme.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: isDark ? BorderSide(color: Colors.white.withAlpha(20), width: 1) : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => context.push('/tasks/${task.taskId}'),
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top tags: Priority and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${task.priority} Priority',
                        style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.p12),

                // Title
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // Department and Assignee
                Text(
                  'Dept: ${task.department}  |  Assignee: $assigneeName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const Spacer(),

                // Progress Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${task.progress.toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),

                // Due Date
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Due Date: $dueStr',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
