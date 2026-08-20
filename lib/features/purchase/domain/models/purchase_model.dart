import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseModel {
  final String purchaseId;
  final String companyId;
  final String purchaseNumber; // e.g. PUR-0001
  final String? invoiceNumber; // Optional custom invoice number
  final String supplierName;
  final String supplierPhone;
  final String itemName;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalAmount;
  final DateTime purchaseDate;
  final String remarks;
  final String status; // 'Pending', 'Received', 'Cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseModel({
    required this.purchaseId,
    required this.companyId,
    required this.purchaseNumber,
    this.invoiceNumber,
    required this.supplierName,
    required this.supplierPhone,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.purchaseDate,
    required this.remarks,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseModel.fromMap(Map<String, dynamic> map, String id) {
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

    return PurchaseModel(
      purchaseId: id,
      companyId: (map['companyId'] ?? '') as String,
      purchaseNumber: (map['purchaseNumber'] ?? '') as String,
      invoiceNumber: map['invoiceNumber'] as String?,
      supplierName: (map['supplierName'] ?? '') as String,
      supplierPhone: (map['supplierPhone'] ?? '') as String,
      itemName: (map['itemName'] ?? '') as String,
      quantity: parseDouble(map['quantity']),
      unit: (map['unit'] ?? 'Nos') as String,
      pricePerUnit: parseDouble(map['pricePerUnit']),
      totalAmount: parseDouble(map['totalAmount']),
      purchaseDate: parseDate(map['purchaseDate']),
      remarks: (map['remarks'] ?? '') as String,
      status: (map['status'] ?? 'Pending') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseId': purchaseId,
      'companyId': companyId,
      'purchaseNumber': purchaseNumber,
      'invoiceNumber': invoiceNumber,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'remarks': remarks,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
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

  PurchaseModel copyWith({
    String? purchaseId,
    String? companyId,
    String? purchaseNumber,
    String? invoiceNumber,
    String? supplierName,
    String? supplierPhone,
    String? itemName,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    double? totalAmount,
    DateTime? purchaseDate,
    String? remarks,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseModel(
      purchaseId: purchaseId ?? this.purchaseId,
      companyId: companyId ?? this.companyId,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalAmount: totalAmount ?? this.totalAmount,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
