import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/task_model.dart';
import '../../domain/repositories/task_repository.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/domain/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl();
});

// Filter state providers
final taskSearchQueryProvider = StateProvider<String>((ref) => '');
final taskDepartmentFilterProvider = StateProvider<String?>((ref) => null);
final taskPriorityFilterProvider = StateProvider<String?>((ref) => null);
final taskStatusFilterProvider = StateProvider<String?>((ref) => null);
final taskDueDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final taskEmployeeFilterProvider = StateProvider<String?>((ref) => null);

// Constants
const List<String> kTaskStatuses = [
  'Pending Acceptance',
  'Pending',
  'Accepted',
  'In Progress',
  'Completed',
  'Rejected',
  'Cancelled',
  'On Hold',
];

const List<String> kTaskPriorities = [
  'Low',
  'Medium',
  'High',
  'Critical',
];

// Real-time stream of all tasks for the company
final companyTasksStreamProvider = StreamProvider<List<TaskModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(taskRepositoryProvider).streamTasks(companyId);
});

// Stream of filtered tasks
final filteredTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(<TaskModel>[]);
  }

  final companyId = user.companyId;
  final role = user.role;
  final isEmployee = role == 'Employee';

  final tasksStream = ref.watch(taskRepositoryProvider).streamTasks(companyId);

  final query = ref.watch(taskSearchQueryProvider).trim().toLowerCase();
  final dept = ref.watch(taskDepartmentFilterProvider);
  final priority = ref.watch(taskPriorityFilterProvider);
  final status = ref.watch(taskStatusFilterProvider);
  final dueDate = ref.watch(taskDueDateFilterProvider);
  final employeeId = ref.watch(taskEmployeeFilterProvider);

  return tasksStream.map((list) {
    return list.where((task) {
      // 1. Employee access restriction: Employee sees only their assigned tasks
      if (isEmployee && task.assignedToEmployeeId != user.employeeId) {
        return false;
      }

      // 2. Search Query (Matches Title, Description, Department, Assignee, Priority)
      if (query.isNotEmpty) {
        final titleMatch = task.title.toLowerCase().contains(query);
        final descMatch = task.description.toLowerCase().contains(query);
        final deptMatch = task.department.toLowerCase().contains(query);
        final priorityMatch = task.priority.toLowerCase().contains(query);
        if (!titleMatch && !descMatch && !deptMatch && !priorityMatch) {
          return false;
        }
      }

      // 3. Department Filter
      if (dept != null && dept != 'All' && task.department != dept) {
        return false;
      }

      // 4. Priority Filter
      if (priority != null && priority != 'All' && task.priority != priority) {
        return false;
      }

      // 5. Status Filter
      if (status != null && status != 'All' && task.status != status) {
        return false;
      }

      // 6. Employee Filter (for managers only)
      if (!isEmployee && employeeId != null && employeeId != 'All' && task.assignedToEmployeeId != employeeId) {
        return false;
      }

      // 7. Due Date Filter
      if (dueDate != null) {
        final taskDue = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
        final filterDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (taskDue != filterDue) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

// Single Task details stream
final taskDetailsStreamProvider = StreamProvider.family<TaskModel?, String>((ref, taskId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(taskRepositoryProvider).streamTaskById(companyId, taskId);
});

// Task statistics model
class TaskStats {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int overdue;

  const TaskStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.overdue,
  });
}

// Task stats provider
final taskStatsProvider = StreamProvider<TaskStats>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(const TaskStats(total: 0, pending: 0, inProgress: 0, completed: 0, overdue: 0));
  }

  final isEmployee = user.role == 'Employee';
  final tasksStream = ref.watch(taskRepositoryProvider).streamTasks(user.companyId);

  return tasksStream.map((list) {
    final userTasks = isEmployee
        ? list.where((t) => t.assignedToEmployeeId == user.employeeId).toList()
        : list;

    int total = userTasks.length;
    int pending = 0;
    int inProgress = 0;
    int completed = 0;
    int overdue = 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final task in userTasks) {
      if (task.status == 'Pending') {
        pending++;
      } else if (task.status == 'In Progress') {
        inProgress++;
      } else if (task.status == 'Completed') {
        completed++;
      }

      // Overdue check
      if (task.status != 'Completed' && task.status != 'Cancelled') {
        final taskDue = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
        if (taskDue.isBefore(todayDate)) {
          overdue++;
        }
      }
    }

    return TaskStats(
      total: total,
      pending: pending,
      inProgress: inProgress,
      completed: completed,
      overdue: overdue,
    );
  });
});

// Stream of employees for task assigner dropdown filter
final companyEmployeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(employeeRepositoryProvider).streamEmployees(companyId);
});

// Notification architecture placeholders
// Notification helper
class TaskNotificationService {
  static Future<void> notifyNewTaskAssigned(WidgetRef ref, TaskModel task, String companyId, String managerName) async {
    final authState = ref.read(authProvider);
    final managerUid = authState.user?.uid ?? '';
    await ref.read(notificationServiceProvider).notifyNewTaskAssigned(
      companyId: companyId,
      taskId: task.taskId,
      taskTitle: task.title,
      assignedToEmployeeId: task.assignedToEmployeeId,
      managerUid: managerUid,
      managerName: managerName,
    );
  }

  static Future<void> notifyTaskStatusChanged(WidgetRef ref, TaskModel task, String status, String userName) async {
    final authState = ref.read(authProvider);
    final userUid = authState.user?.uid ?? '';
    
    // Check for late completion trigger
    if (status == 'Completed' && task.completionTiming == 'Late') {
      await ref.read(notificationServiceProvider).notifyTaskCompletedLate(
        companyId: task.companyId,
        taskId: task.taskId,
        taskTitle: task.title,
        lateDurationMinutes: task.lateDurationMinutes ?? 0,
        reason: task.lateReason ?? 'None',
        employeeUid: userUid,
        employeeName: userName,
      );
    } else {
      // Handles standard Completed, Accepted, Rejected
      await ref.read(notificationServiceProvider).notifyTaskStatusChanged(
        companyId: task.companyId,
        taskId: task.taskId,
        taskTitle: task.title,
        status: status,
        employeeUid: userUid,
        employeeName: userName,
        reason: status == 'Rejected' ? task.rejectionReason : task.lateReason,
      );
    }
  }
}
