import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String saleId;
  final String companyId;
  final String? partyId; // Linked Party reference ID
  final String saleNumber; // e.g. SAL-0001
  final String? invoiceNumber; // Auto-generated or custom invoice number
  final String customerName;
  final String customerPhone;
  final String partyType;
  final String vendorCode;
  final String contactPersonName;
  final String email;
  final String gstin;
  final String state;
  final String stateCode;
  final String address;
  final String itemNumber; // Item Number e.g. ITM-001
  final String itemName;
  final String hsnCode; // HSN / SAC Code
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalAmount;
  final DateTime saleDate;
  final String remarks;
  final String status; // 'Pending', 'Delivered', 'Cancelled'
  final String approvalStatus; // 'Approved', 'Pending Approval'
  final String? createdByUid;
  final String? createdByName;
  final String? createdByRole;
  final String? lastModifiedByUid;
  final String? lastModifiedByName;
  final String? lastModifiedByRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SaleModel({
    required this.saleId,
    required this.companyId,
    this.partyId,
    required this.saleNumber,
    this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    this.partyType = '',
    this.vendorCode = '',
    this.contactPersonName = '',
    this.email = '',
    this.gstin = '',
    this.state = '',
    this.stateCode = '',
    this.address = '',
    this.itemNumber = '',
    required this.itemName,
    this.hsnCode = '',
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.saleDate,
    required this.remarks,
    required this.status,
    this.approvalStatus = 'Approved',
    this.createdByUid,
    this.createdByName,
    this.createdByRole,
    this.lastModifiedByUid,
    this.lastModifiedByName,
    this.lastModifiedByRole,
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
      partyId: map['partyId'] as String?,
      saleNumber: (map['saleNumber'] ?? '') as String,
      invoiceNumber: map['invoiceNumber'] as String?,
      customerName: (map['customerName'] ?? '') as String,
      customerPhone: (map['customerPhone'] ?? '') as String,
      partyType: (map['partyType'] ?? '') as String,
      vendorCode: (map['vendorCode'] ?? '') as String,
      contactPersonName: (map['contactPersonName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      gstin: (map['gstin'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      stateCode: (map['stateCode'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      itemNumber: (map['itemNumber'] ?? '') as String,
      itemName: (map['itemName'] ?? '') as String,
      hsnCode: (map['hsnCode'] ?? '') as String,
      quantity: parseDouble(map['quantity']),
      unit: (map['unit'] ?? 'Nos') as String,
      pricePerUnit: parseDouble(map['pricePerUnit']),
      totalAmount: parseDouble(map['totalAmount']),
      saleDate: parseDate(map['saleDate']),
      remarks: (map['remarks'] ?? '') as String,
      status: (map['status'] ?? 'Pending') as String,
      approvalStatus: (map['approvalStatus'] ?? 'Approved') as String,
      createdByUid: map['createdByUid'] as String?,
      createdByName: map['createdByName'] as String?,
      createdByRole: map['createdByRole'] as String?,
      lastModifiedByUid: map['lastModifiedByUid'] as String?,
      lastModifiedByName: map['lastModifiedByName'] as String?,
      lastModifiedByRole: map['lastModifiedByRole'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'saleId': saleId,
      'companyId': companyId,
      'partyId': partyId,
      'saleNumber': saleNumber,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'partyType': partyType,
      'vendorCode': vendorCode,
      'contactPersonName': contactPersonName,
      'email': email,
      'gstin': gstin,
      'state': state,
      'stateCode': stateCode,
      'address': address,
      'itemNumber': itemNumber,
      'itemName': itemName,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'unit': unit,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'saleDate': Timestamp.fromDate(saleDate),
      'remarks': remarks,
      'status': status,
      'approvalStatus': approvalStatus,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'lastModifiedByUid': lastModifiedByUid,
      'lastModifiedByName': lastModifiedByName,
      'lastModifiedByRole': lastModifiedByRole,
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
    String? partyId,
    String? saleNumber,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? partyType,
    String? vendorCode,
    String? contactPersonName,
    String? email,
    String? gstin,
    String? state,
    String? stateCode,
    String? address,
    String? itemNumber,
    String? itemName,
    String? hsnCode,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    double? totalAmount,
    DateTime? saleDate,
    String? remarks,
    String? status,
    String? approvalStatus,
    String? createdByUid,
    String? createdByName,
    String? createdByRole,
    String? lastModifiedByUid,
    String? lastModifiedByName,
    String? lastModifiedByRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleModel(
      saleId: saleId ?? this.saleId,
      companyId: companyId ?? this.companyId,
      partyId: partyId ?? this.partyId,
      saleNumber: saleNumber ?? this.saleNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      partyType: partyType ?? this.partyType,
      vendorCode: vendorCode ?? this.vendorCode,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      address: address ?? this.address,
      itemNumber: itemNumber ?? this.itemNumber,
      itemName: itemName ?? this.itemName,
      hsnCode: hsnCode ?? this.hsnCode,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalAmount: totalAmount ?? this.totalAmount,
      saleDate: saleDate ?? this.saleDate,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
      lastModifiedByUid: lastModifiedByUid ?? this.lastModifiedByUid,
      lastModifiedByName: lastModifiedByName ?? this.lastModifiedByName,
      lastModifiedByRole: lastModifiedByRole ?? this.lastModifiedByRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
