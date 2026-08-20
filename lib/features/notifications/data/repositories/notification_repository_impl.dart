import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/notification_model.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createNotification(String companyId, NotificationModel notification) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .doc(notification.notificationId)
        .set(notification.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateNotification(String companyId, NotificationModel notification) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .doc(notification.notificationId)
        .update(notification.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteNotification(String companyId, String notificationId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  Stream<List<NotificationModel>> streamNotifications(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<Set<String>> streamReadNotificationIds(String companyId, String employeeId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .collection('read_notifications')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  @override
  Future<void> markAsRead(String companyId, String employeeId, String notificationId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .collection('read_notifications')
        .doc(notificationId)
        .set({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markAsUnread(String companyId, String employeeId, String notificationId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .collection('read_notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  Future<void> markAllAsRead(String companyId, String employeeId, List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    // Firestore batch write supports up to 500 operations
    final chunks = <List<String>>[];
    const chunkSize = 400;
    for (var i = 0; i < notificationIds.length; i += chunkSize) {
      chunks.add(
        notificationIds.sublist(
          i,
          i + chunkSize > notificationIds.length ? notificationIds.length : i + chunkSize,
        ),
      );
    }

    for (final chunk in chunks) {
      final batch = _firestore.batch();
      for (final id in chunk) {
        final ref = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('employees')
            .doc(employeeId)
            .collection('read_notifications')
            .doc(id);
        batch.set(ref, {
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
