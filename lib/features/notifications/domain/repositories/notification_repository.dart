import '../models/notification_model.dart';

abstract class NotificationRepository {
  /// Creates a new notification or announcement
  Future<void> createNotification(String companyId, NotificationModel notification);

  /// Updates an existing notification or announcement (e.g. editing text, pinning)
  Future<void> updateNotification(String companyId, NotificationModel notification);

  /// Deletes a notification or announcement
  Future<void> deleteNotification(String companyId, String notificationId);

  /// Streams all notifications for the given company
  Stream<List<NotificationModel>> streamNotifications(String companyId);

  /// Streams the set of notification IDs that the employee has read
  Stream<Set<String>> streamReadNotificationIds(String companyId, String employeeId);

  /// Marks a specific notification as read for a given employee
  Future<void> markAsRead(String companyId, String employeeId, String notificationId);

  /// Marks a specific notification as unread for a given employee
  Future<void> markAsUnread(String companyId, String employeeId, String notificationId);

  /// Marks all specified notifications as read for a given employee
  Future<void> markAllAsRead(String companyId, String employeeId, List<String> notificationIds);
}
