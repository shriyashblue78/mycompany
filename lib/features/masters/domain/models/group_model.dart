import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String companyId;
  final String groupName;
  final String? parentGroupId; // null or empty for root group
  final String? parentGroupName; // denormalized for efficient display
  final DateTime createdAt;
  final DateTime updatedAt;

  const GroupModel({
    required this.groupId,
    required this.companyId,
    required this.groupName,
    this.parentGroupId,
    this.parentGroupName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return GroupModel(
      groupId: id,
      companyId: (map['companyId'] ?? '') as String,
      groupName: (map['groupName'] ?? '') as String,
      parentGroupId: map['parentGroupId'] as String?,
      parentGroupName: map['parentGroupName'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'groupName': groupName.trim(),
      'parentGroupId': (parentGroupId != null && parentGroupId!.isNotEmpty) ? parentGroupId : null,
      'parentGroupName': (parentGroupName != null && parentGroupName!.isNotEmpty) ? parentGroupName : null,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  GroupModel copyWith({
    String? groupId,
    String? companyId,
    String? groupName,
    String? parentGroupId,
    String? parentGroupName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearParent = false,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      companyId: companyId ?? this.companyId,
      groupName: groupName ?? this.groupName,
      parentGroupId: clearParent ? null : (parentGroupId ?? this.parentGroupId),
      parentGroupName: clearParent ? null : (parentGroupName ?? this.parentGroupName),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
