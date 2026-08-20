import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItemModel {
  final String itemId;
  final String companyId;
  final String itemName;
  final String category;
  final double currentStock;
  final String unit;
  final String? supplierName;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields
  final DateTime date;
  final String documentNumber;
  final String partNumber;
  final String process;
  final bool withMaterial;

  const InventoryItemModel({
    required this.itemId,
    required this.companyId,
    required this.itemName,
    required this.category,
    required this.currentStock,
    required this.unit,
    this.supplierName,
    required this.createdAt,
    required this.updatedAt,
    required this.date,
    required this.documentNumber,
    required this.partNumber,
    required this.process,
    required this.withMaterial,
  });

  factory InventoryItemModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return InventoryItemModel(
      itemId: id,
      companyId: (map['companyId'] ?? '') as String,
      itemName: (map['itemName'] ?? '') as String,
      category: (map['category'] ?? 'Others') as String,
      currentStock: parseDouble(map['currentStock']),
      unit: (map['unit'] ?? 'Nos') as String,
      supplierName: map['supplierName'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      date: parseDate(map['date']),
      documentNumber: (map['documentNumber'] ?? '') as String,
      partNumber: (map['partNumber'] ?? '') as String,
      process: (map['process'] ?? '') as String,
      withMaterial: (map['withMaterial'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'companyId': companyId,
      'itemName': itemName,
      'category': category,
      'currentStock': currentStock,
      'unit': unit,
      'supplierName': supplierName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'date': Timestamp.fromDate(date),
      'documentNumber': documentNumber,
      'partNumber': partNumber,
      'process': process,
      'withMaterial': withMaterial,
    };
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = toMap();
    if (isUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map.remove('createdAt');
    } else {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  InventoryItemModel copyWith({
    String? itemId,
    String? companyId,
    String? itemName,
    String? category,
    double? currentStock,
    String? unit,
    String? supplierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? date,
    String? documentNumber,
    String? partNumber,
    String? process,
    bool? withMaterial,
  }) {
    return InventoryItemModel(
      itemId: itemId ?? this.itemId,
      companyId: companyId ?? this.companyId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      unit: unit ?? this.unit,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      date: date ?? this.date,
      documentNumber: documentNumber ?? this.documentNumber,
      partNumber: partNumber ?? this.partNumber,
      process: process ?? this.process,
      withMaterial: withMaterial ?? this.withMaterial,
    );
  }
}
