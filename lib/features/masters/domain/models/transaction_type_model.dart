import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionTypeModel {
  final String typeId;
  final String companyId;
  final String typeName;
  final String? category; // 'Inward', 'Outward', 'Internal Transfer', 'Adjustment'
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionTypeModel({
    required this.typeId,
    required this.companyId,
    required this.typeName,
    this.category,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionTypeModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return TransactionTypeModel(
      typeId: id,
      companyId: (map['companyId'] ?? '') as String,
      typeName: (map['typeName'] ?? '') as String,
      category: map['category'] as String?,
      description: map['description'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'typeName': typeName.trim(),
      if (category != null && category!.trim().isNotEmpty) 'category': category!.trim(),
      if (description != null && description!.trim().isNotEmpty) 'description': description!.trim(),
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TransactionTypeModel copyWith({
    String? typeId,
    String? companyId,
    String? typeName,
    String? category,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionTypeModel(
      typeId: typeId ?? this.typeId,
      companyId: companyId ?? this.companyId,
      typeName: typeName ?? this.typeName,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
