import 'package:cloud_firestore/cloud_firestore.dart';

class RejectionReasonModel {
  final String reasonId;
  final String companyId;
  final String reasonName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RejectionReasonModel({
    required this.reasonId,
    required this.companyId,
    required this.reasonName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RejectionReasonModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return RejectionReasonModel(
      reasonId: id,
      companyId: (map['companyId'] ?? '') as String,
      reasonName: (map['reasonName'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'reasonName': reasonName.trim(),
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RejectionReasonModel copyWith({
    String? reasonId,
    String? companyId,
    String? reasonName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RejectionReasonModel(
      reasonId: reasonId ?? this.reasonId,
      companyId: companyId ?? this.companyId,
      reasonName: reasonName ?? this.reasonName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
