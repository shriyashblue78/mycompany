import 'package:cloud_firestore/cloud_firestore.dart';

class StateMasterModel {
  final String stateId;
  final String companyId;
  final String stateName;
  final String stateCode; // 2-digit official GST state code e.g. "27"
  final DateTime createdAt;
  final DateTime updatedAt;

  const StateMasterModel({
    required this.stateId,
    required this.companyId,
    required this.stateName,
    required this.stateCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StateMasterModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return StateMasterModel(
      stateId: id,
      companyId: (map['companyId'] ?? '') as String,
      stateName: (map['stateName'] ?? '') as String,
      stateCode: (map['stateCode'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'stateName': stateName.trim(),
      'stateCode': stateCode.trim(),
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  StateMasterModel copyWith({
    String? stateId,
    String? companyId,
    String? stateName,
    String? stateCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StateMasterModel(
      stateId: stateId ?? this.stateId,
      companyId: companyId ?? this.companyId,
      stateName: stateName ?? this.stateName,
      stateCode: stateCode ?? this.stateCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
