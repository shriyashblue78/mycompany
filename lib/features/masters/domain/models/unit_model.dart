import 'package:cloud_firestore/cloud_firestore.dart';

class UnitModel {
  final String unitId;
  final String companyId;
  final String unit;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UnitModel({
    required this.unitId,
    required this.companyId,
    required this.unit,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return UnitModel(
      unitId: id,
      companyId: (map['companyId'] ?? '') as String,
      unit: (map['unit'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'unit': unit.trim(),
      'description': description.trim(),
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UnitModel copyWith({
    String? unitId,
    String? companyId,
    String? unit,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitModel(
      unitId: unitId ?? this.unitId,
      companyId: companyId ?? this.companyId,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
