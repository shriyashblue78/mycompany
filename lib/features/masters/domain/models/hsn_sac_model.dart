import 'package:cloud_firestore/cloud_firestore.dart';

class HsnSacModel {
  final String hsnSacId;
  final String companyId;
  final String code; // HSN/SAC Code
  final String description; // Description
  final String type; // 'Goods' or 'Services'
  final String? gstCategory; // e.g. "GST 18%", "GST 12%", "Exempted"
  final DateTime createdAt;
  final DateTime updatedAt;

  const HsnSacModel({
    required this.hsnSacId,
    required this.companyId,
    required this.code,
    required this.description,
    this.type = 'Goods',
    this.gstCategory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HsnSacModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return HsnSacModel(
      hsnSacId: id,
      companyId: (map['companyId'] ?? '') as String,
      code: (map['code'] ?? map['hsnCode'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      type: (map['type'] ?? 'Goods') as String,
      gstCategory: map['gstCategory'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'code': code.trim(),
      'description': description.trim(),
      'type': type,
      'gstCategory': (gstCategory != null && gstCategory!.trim().isNotEmpty) ? gstCategory!.trim() : null,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  HsnSacModel copyWith({
    String? hsnSacId,
    String? companyId,
    String? code,
    String? description,
    String? type,
    String? gstCategory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HsnSacModel(
      hsnSacId: hsnSacId ?? this.hsnSacId,
      companyId: companyId ?? this.companyId,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      gstCategory: gstCategory ?? this.gstCategory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
