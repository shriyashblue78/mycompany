import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String categoryId;
  final String companyId;
  final String categoryName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.categoryId,
    required this.companyId,
    required this.categoryName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return CategoryModel(
      categoryId: id,
      companyId: (map['companyId'] ?? '') as String,
      categoryName: (map['categoryName'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'categoryName': categoryName.trim(),
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CategoryModel copyWith({
    String? categoryId,
    String? companyId,
    String? categoryName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      companyId: companyId ?? this.companyId,
      categoryName: categoryName ?? this.categoryName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
