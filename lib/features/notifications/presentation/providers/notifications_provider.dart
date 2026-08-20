import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/notification_model.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';

import '../../domain/services/notification_service.dart';

// Repository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl();
});

// Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    notificationRepository: ref.watch(notificationRepositoryProvider),
    employeeRepository: ref.watch(employeeRepositoryProvider),
    ref: ref,
  );
});

final pendingNotificationRouteProvider = StateProvider<String?>((ref) => null);

// Constants
const List<String> kNotificationTypes = [
  'Announcement',
  'Task Update',
  'Leave Update',
  'Attendance Reminder',
  'General',
];

const List<String> kNotificationPriorities = [
  'Low',
  'Medium',
  'High',
  'Critical',
];

// Helper wrapper model
class NotificationWithReadState {
  final NotificationModel notification;
  final bool isRead;

  const NotificationWithReadState({
    required this.notification,
    required this.isRead,
  });

  NotificationWithReadState copyWith({
    NotificationModel? notification,
    bool? isRead,
  }) {
    return NotificationWithReadState(
      notification: notification ?? this.notification,
      isRead: isRead ?? this.isRead,
    );
  }
}

// Filter State Providers
final notificationSearchQueryProvider = StateProvider<String>((ref) => '');
final notificationTypeFilterProvider = StateProvider<String?>((ref) => null);
final notificationPriorityFilterProvider = StateProvider<String?>((ref) => null);
final notificationReadStatusFilterProvider = StateProvider<String?>((ref) => null); // 'All', 'Read', 'Unread'
final notificationDateFilterProvider = StateProvider<DateTime?>((ref) => null);

// Raw stream of all notifications for the company
final rawNotificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(notificationRepositoryProvider).streamNotifications(companyId);
});

// Stream of read notification IDs for the current employee
final readNotificationIdsStreamProvider = StreamProvider<Set<String>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(<String>{});
  }
  return ref
      .watch(notificationRepositoryProvider)
      .streamReadNotificationIds(user.companyId, user.employeeId);
});

// Filtered and audience-targeted notifications stream
final filteredNotificationsProvider = StreamProvider<List<NotificationWithReadState>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value([]);
  }

  final role = user.role;
  final dept = user.department;
  final employeeId = user.employeeId;

  final rawNotificationsAsync = ref.watch(rawNotificationsStreamProvider);
  final readIdsAsync = ref.watch(readNotificationIdsStreamProvider);

  // Combine both streams
  return rawNotificationsAsync.when(
    loading: () => Stream.value(<NotificationWithReadState>[]),
    error: (err, stack) => Stream.value(<NotificationWithReadState>[]),
    data: (notifications) {
      return readIdsAsync.when(
        loading: () => Stream.value(<NotificationWithReadState>[]),
        error: (err, stack) => Stream.value(<NotificationWithReadState>[]),
        data: (readIds) {
          final query = ref.watch(notificationSearchQueryProvider).trim().toLowerCase();
          final filterType = ref.watch(notificationTypeFilterProvider);
          final filterPriority = ref.watch(notificationPriorityFilterProvider);
          final filterRead = ref.watch(notificationReadStatusFilterProvider);
          final filterDate = ref.watch(notificationDateFilterProvider);

          final now = DateTime.now();

          // 1. Audience Targeting & Scheduling Filter
          final visibleNotifications = notifications.where((notification) {
            final createdByMe = notification.createdByUid == user.uid;

            // Managers (Owner, HR) see everything. Others are targeted.
            bool isTargeted = false;
            if (role == 'Owner' || role == 'HR') {
              isTargeted = true;
            } else if (role == 'Supervisor') {
              // Supervisors see company-wide, their department, or created by them, or employee-targeted
              if (notification.targetType == 'Company') {
                isTargeted = true;
              } else if (notification.targetType == 'Department' &&
                  notification.targetDepartment == dept) {
                isTargeted = true;
              } else if (notification.targetType == 'Employee' &&
                  notification.targetEmployeeIds.contains(employeeId)) {
                isTargeted = true;
              } else if (createdByMe) {
                isTargeted = true;
              }
            } else {
              // Employees see company-wide, department, or individual targets
              if (notification.targetType == 'Company') {
                isTargeted = true;
              } else if (notification.targetType == 'Department' &&
                  notification.targetDepartment == dept) {
                isTargeted = true;
              } else if (notification.targetType == 'Employee' &&
                  notification.targetEmployeeIds.contains(employeeId)) {
                isTargeted = true;
              }
            }

            if (!isTargeted) return false;

            // Normal Employees (and Supervisors for non-owned posts) only see active scheduled and non-expired notifications
            final bypassScheduling = role == 'Owner' || role == 'HR' || createdByMe;
            if (!bypassScheduling) {
              if (notification.scheduledAt != null && notification.scheduledAt!.isAfter(now)) {
                return false;
              }
              if (notification.expiresAt != null && notification.expiresAt!.isBefore(now)) {
                return false;
              }
            }

            return true;
          });

          // 2. Map to Read State & Apply Search / Dropdown filters
          final mapped = visibleNotifications.map((n) {
            return NotificationWithReadState(
              notification: n,
              isRead: readIds.contains(n.notificationId),
            );
          }).where((item) {
            final notification = item.notification;

            // Search by title or message
            if (query.isNotEmpty) {
              final titleMatch = notification.title.toLowerCase().contains(query);
              final msgMatch = notification.message.toLowerCase().contains(query);
              if (!titleMatch && !msgMatch) return false;
            }

            // Filter by Type
            if (filterType != null && filterType != 'All' && notification.type != filterType) {
              return false;
            }

            // Filter by Priority
            if (filterPriority != null &&
                filterPriority != 'All' &&
                notification.priority != filterPriority) {
              return false;
            }

            // Filter by Read/Unread Status
            if (filterRead != null && filterRead != 'All') {
              if (filterRead == 'Read' && !item.isRead) return false;
              if (filterRead == 'Unread' && item.isRead) return false;
            }

            // Filter by Date (same day check)
            if (filterDate != null) {
              final notifDay = DateTime(
                notification.createdAt.year,
                notification.createdAt.month,
                notification.createdAt.day,
              );
              final targetDay = DateTime(
                filterDate.year,
                filterDate.month,
                filterDate.day,
              );
              if (notifDay != targetDay) return false;
            }

            return true;
          }).toList();

          return Stream.value(mapped);
        },
      );
    },
  );
});

// Stats structure
class NotificationStats {
  final int total;
  final int unread;
  final int pinned;
  final List<NotificationWithReadState> recentAnnouncements;

  const NotificationStats({
    required this.total,
    required this.unread,
    required this.pinned,
    required this.recentAnnouncements,
  });
}

// Stream provider for stats calculation
final notificationStatsProvider = StreamProvider<NotificationStats>((ref) {
  final filteredAsync = ref.watch(filteredNotificationsProvider);

  return filteredAsync.when(
    loading: () => Stream.value(const NotificationStats(
      total: 0,
      unread: 0,
      pinned: 0,
      recentAnnouncements: [],
    )),
    error: (err, stack) => Stream.value(const NotificationStats(
      total: 0,
      unread: 0,
      pinned: 0,
      recentAnnouncements: [],
    )),
    data: (list) {
      final total = list.length;
      final unread = list.where((item) => !item.isRead).length;
      final pinned = list.where((item) => item.notification.isPinned).length;

      // Filter recent announcements (type == 'Announcement', up to 5)
      final recent = list
          .where((item) => item.notification.type == 'Announcement')
          .take(5)
          .toList();

      return Stream.value(NotificationStats(
        total: total,
        unread: unread,
        pinned: pinned,
        recentAnnouncements: recent,
      ));
    },
  );
});

// Detail Stream Provider
final notificationDetailProvider = StreamProvider.family<NotificationWithReadState?, String>((ref, notifId) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(null);
  }

  final notificationsStream = ref.watch(notificationRepositoryProvider).streamNotifications(user.companyId);
  final readIdsStream = ref.watch(notificationRepositoryProvider).streamReadNotificationIds(user.companyId, user.employeeId);

  return notificationsStream.asyncMap((list) async {
    final index = list.indexWhere((n) => n.notificationId == notifId);
    if (index == -1) return null;
    final notif = list[index];

    final readIds = await readIdsStream.first;
    return NotificationWithReadState(
      notification: notif,
      isRead: readIds.contains(notifId),
    );
  });
});
