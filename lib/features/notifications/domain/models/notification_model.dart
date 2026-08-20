import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String companyId;
  final String title;
  final String message;
  final String type; // 'Announcement', 'Task Update', 'Leave Update', 'Attendance Reminder', 'General'
  final String priority; // 'Low', 'Medium', 'High', 'Critical'
  final String targetType; // 'Company', 'Department', 'Employee'
  final String? targetDepartment;
  final List<String> targetEmployeeIds;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final bool isPinned;
  final String? relatedDocumentId;
  final String? actionOrStatus;

  const NotificationModel({
    required this.notificationId,
    required this.companyId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.targetType,
    this.targetDepartment,
    required this.targetEmployeeIds,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.scheduledAt,
    this.expiresAt,
    required this.isPinned,
    this.relatedDocumentId,
    this.actionOrStatus,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return NotificationModel(
      notificationId: id,
      companyId: (map['companyId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      message: (map['message'] ?? '') as String,
      type: (map['type'] ?? 'General') as String,
      priority: (map['priority'] ?? 'Low') as String,
      targetType: (map['targetType'] ?? 'Company') as String,
      targetDepartment: map['targetDepartment'] as String?,
      targetEmployeeIds: List<String>.from(map['targetEmployeeIds'] ?? []),
      createdByUid: (map['createdByUid'] ?? '') as String,
      createdByName: (map['createdByName'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      scheduledAt: parseDateNullable(map['scheduledAt']),
      expiresAt: parseDateNullable(map['expiresAt']),
      isPinned: (map['isPinned'] ?? false) as bool,
      relatedDocumentId: map['relatedDocumentId'] as String?,
      actionOrStatus: map['actionOrStatus'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'companyId': companyId,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'targetType': targetType,
      'targetDepartment': targetDepartment,
      'targetEmployeeIds': targetEmployeeIds,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isPinned': isPinned,
      'relatedDocumentId': relatedDocumentId,
      'actionOrStatus': actionOrStatus,
    };
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = toMap();
    if (isUpdate) {
      map.remove('createdAt');
    } else {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  NotificationModel copyWith({
    String? notificationId,
    String? companyId,
    String? title,
    String? message,
    String? type,
    String? priority,
    String? targetType,
    String? targetDepartment,
    List<String>? targetEmployeeIds,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    bool? isPinned,
    String? relatedDocumentId,
    String? actionOrStatus,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      targetType: targetType ?? this.targetType,
      targetDepartment: targetDepartment ?? this.targetDepartment,
      targetEmployeeIds: targetEmployeeIds ?? this.targetEmployeeIds,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isPinned: isPinned ?? this.isPinned,
      relatedDocumentId: relatedDocumentId ?? this.relatedDocumentId,
      actionOrStatus: actionOrStatus ?? this.actionOrStatus,
    );
  }
}
