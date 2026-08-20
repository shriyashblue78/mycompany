import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/leave_model.dart';
import '../../domain/repositories/leave_repository.dart';
import '../../data/repositories/leave_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

// Repository Provider
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepositoryImpl();
});

// Filter state providers
final leaveSearchQueryProvider = StateProvider<String>((ref) => '');
final leaveDepartmentFilterProvider = StateProvider<String?>((ref) => null);
final leaveTypeFilterProvider = StateProvider<String?>((ref) => null);
final leaveStatusFilterProvider = StateProvider<String?>((ref) => null);
final leaveStartDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final leaveEndDateFilterProvider = StateProvider<DateTime?>((ref) => null);

// Constants
const List<String> kLeaveTypes = [
  'Casual Leave',
  'Sick Leave',
  'Earned Leave',
  'Half Day',
  'Work From Home',
  'Unpaid Leave',
];

const List<String> kLeaveStatuses = [
  'Pending',
  'Approved',
  'Rejected',
  'Cancelled',
];

// Real-time stream of all leaves for the company
final companyLeavesStreamProvider = StreamProvider<List<LeaveModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(leaveRepositoryProvider).streamLeaves(companyId);
});

// Stream of filtered leaves
final filteredLeavesProvider = StreamProvider<List<LeaveModel>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(<LeaveModel>[]);
  }

  final companyId = user.companyId;
  final role = user.role;
  final isEmployee = role == 'Employee';
  final isSupervisor = role == 'Supervisor';

  final leavesStream = ref.watch(leaveRepositoryProvider).streamLeaves(companyId);

  final query = ref.watch(leaveSearchQueryProvider).trim().toLowerCase();
  final dept = ref.watch(leaveDepartmentFilterProvider);
  final type = ref.watch(leaveTypeFilterProvider);
  final status = ref.watch(leaveStatusFilterProvider);
  final startFilter = ref.watch(leaveStartDateFilterProvider);
  final endFilter = ref.watch(leaveEndDateFilterProvider);

  return leavesStream.map((list) {
    return list.where((leave) {
      // 1. Role boundaries
      if (isEmployee && leave.employeeId != user.employeeId) {
        return false;
      }
      if (isSupervisor && leave.department != user.department) {
        // Supervisors can only review leaves from their own department
        return false;
      }

      // 2. Search Query (Employee Name, Reason)
      if (query.isNotEmpty) {
        final nameMatch = leave.employeeName.toLowerCase().contains(query);
        final reasonMatch = leave.reason.toLowerCase().contains(query);
        if (!nameMatch && !reasonMatch) {
          return false;
        }
      }

      // 3. Department Filter
      if (dept != null && dept != 'All' && leave.department != dept) {
        return false;
      }

      // 4. Leave Type Filter
      if (type != null && type != 'All' && leave.leaveType != type) {
        return false;
      }

      // 5. Status Filter
      if (status != null && status != 'All' && leave.status != status) {
        return false;
      }

      // 6. Date Range Filter
      if (startFilter != null) {
        final leaveStart = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        final startRange = DateTime(startFilter.year, startFilter.month, startFilter.day);
        if (leaveStart.isBefore(startRange)) {
          return false;
        }
      }
      if (endFilter != null) {
        final leaveEnd = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
        final endRange = DateTime(endFilter.year, endFilter.month, endFilter.day);
        if (leaveEnd.isAfter(endRange)) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

// Single leave details stream
final leaveDetailsStreamProvider = StreamProvider.family<LeaveModel?, String>((ref, leaveId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(leaveRepositoryProvider).streamLeaveById(companyId, leaveId);
});

// Leave dashboard stats
class LeaveStats {
  final int totalRequests;
  final int pending;
  final int approved;
  final int rejected;
  final int onLeaveToday;

  const LeaveStats({
    required this.totalRequests,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.onLeaveToday,
  });
}

// Stats provider
final leaveStatsProvider = StreamProvider<LeaveStats>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(const LeaveStats(totalRequests: 0, pending: 0, approved: 0, rejected: 0, onLeaveToday: 0));
  }

  final isEmployee = user.role == 'Employee';
  final isSupervisor = user.role == 'Supervisor';
  final leavesStream = ref.watch(leaveRepositoryProvider).streamLeaves(user.companyId);

  return leavesStream.map((list) {
    // Role isolation for dashboard counters
    final filtered = list.where((leave) {
      if (isEmployee) return leave.employeeId == user.employeeId;
      if (isSupervisor) return leave.department == user.department;
      return true;
    }).toList();

    int totalRequests = filtered.length;
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int onLeaveToday = 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final leave in filtered) {
      if (leave.status == 'Pending') {
        pending++;
      } else if (leave.status == 'Approved') {
        approved++;
      } else if (leave.status == 'Rejected') {
        rejected++;
      }

      // Check if on leave today (Approved leaves only)
      if (leave.status == 'Approved') {
        final start = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        final end = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
        if (!todayDate.isBefore(start) && !todayDate.isAfter(end)) {
          onLeaveToday++;
        }
      }
    }

    return LeaveStats(
      totalRequests: totalRequests,
      pending: pending,
      approved: approved,
      rejected: rejected,
      onLeaveToday: onLeaveToday,
    );
  });
});

// Provider for list of employees on leave today
final onLeaveEmployeesTodayProvider = StreamProvider<List<LeaveModel>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value([]);
  }

  final isEmployee = user.role == 'Employee';
  final isSupervisor = user.role == 'Supervisor';
  final leavesStream = ref.watch(leaveRepositoryProvider).streamLeaves(user.companyId);

  return leavesStream.map((list) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return list.where((leave) {
      if (leave.status != 'Approved') return false;
      if (isEmployee && leave.employeeId != user.employeeId) return false;
      if (isSupervisor && leave.department != user.department) return false;

      final start = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final end = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      return !todayDate.isBefore(start) && !todayDate.isAfter(end);
    }).toList();
  });
});

// Notifications delegation
class LeaveNotificationService {
  static void notifyLeaveApplied(WidgetRef ref, LeaveModel leave) {
    ref.read(notificationServiceProvider).notifyLeaveSubmitted(
      companyId: leave.companyId,
      leaveId: leave.leaveId,
      employeeName: leave.employeeName,
      leaveType: leave.leaveType,
      startDate: leave.startDate,
      endDate: leave.endDate,
      userUid: leave.uid,
    );
  }

  static void notifyLeaveApproved(WidgetRef ref, LeaveModel leave) {
    final authState = ref.read(authProvider);
    final managerUid = authState.user?.uid ?? '';
    final managerName = authState.user?.name ?? 'Manager';
    ref.read(notificationServiceProvider).notifyLeaveStatusChanged(
      companyId: leave.companyId,
      leaveId: leave.leaveId,
      targetEmployeeId: leave.employeeId,
      status: 'Approved',
      startDate: leave.startDate,
      endDate: leave.endDate,
      managerUid: managerUid,
      managerName: managerName,
    );
  }

  static void notifyLeaveRejected(WidgetRef ref, LeaveModel leave) {
    final authState = ref.read(authProvider);
    final managerUid = authState.user?.uid ?? '';
    final managerName = authState.user?.name ?? 'Manager';
    ref.read(notificationServiceProvider).notifyLeaveStatusChanged(
      companyId: leave.companyId,
      leaveId: leave.leaveId,
      targetEmployeeId: leave.employeeId,
      status: 'Rejected',
      startDate: leave.startDate,
      endDate: leave.endDate,
      managerUid: managerUid,
      managerName: managerName,
    );
  }
}
