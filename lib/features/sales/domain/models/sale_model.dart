import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String saleId;
  final String companyId;
  final String saleNumber; // e.g. SAL-0001
  final String? invoiceNumber; // Optional custom invoice number
  final String customerName;
  final String customerPhone;
  final String itemName;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalAmount;
  final DateTime saleDate;
  final String remarks;
  final String status; // 'Pending', 'Delivered', 'Cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const SaleModel({
    required this.saleId,
    required this.companyId,
    required this.saleNumber,
    this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.saleDate,
    required this.remarks,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SaleModel.fromMap(Map<String, dynamic> map, String id) {
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

    return SaleModel(
      saleId: id,
      companyId: (map['companyId'] ?? '') as String,
      saleNumber: (map['saleNumber'] ?? '') as String,
      invoiceNumber: map['invoiceNumber'] as String?,
      customerName: (map['customerName'] ?? '') as String,
      customerPhone: (map['customerPhone'] ?? '') as String,
      itemName: (map['itemName'] ?? '') as String,
      quantity: parseDouble(map['quantity']),
      unit: (map['unit'] ?? 'Nos') as String,
      pricePerUnit: parseDouble(map['pricePerUnit']),
      totalAmount: parseDouble(map['totalAmount']),
      saleDate: parseDate(map['saleDate']),
      remarks: (map['remarks'] ?? '') as String,
      status: (map['status'] ?? 'Pending') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'saleId': saleId,
      'companyId': companyId,
      'saleNumber': saleNumber,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'saleDate': Timestamp.fromDate(saleDate),
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

  SaleModel copyWith({
    String? saleId,
    String? companyId,
    String? saleNumber,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? itemName,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    double? totalAmount,
    DateTime? saleDate,
    String? remarks,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleModel(
      saleId: saleId ?? this.saleId,
      companyId: companyId ?? this.companyId,
      saleNumber: saleNumber ?? this.saleNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalAmount: totalAmount ?? this.totalAmount,
      saleDate: saleDate ?? this.saleDate,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
