import 'package:cloud_firestore/cloud_firestore.dart';

class TaxModel {
  final String taxId;
  final String companyId;
  final String taxCategory; // e.g. "GST 18%", "GST 12%", "Exempted"
  final String shortName; // e.g. "GST18", "GST12"
  final double cgstRate; // %
  final double sgstRate; // %
  final double igstRate; // %
  final double cessRate; // %
  final String remarkOnInvoice; // Remarks printed on invoice
  final String? salesAccount;
  final String? salesAccountOms; // Out-of-State / OMS
  final String? mouldAmortization;
  final String? cgstAccount;
  final String? sgstAccount;
  final String? igstAccount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaxModel({
    required this.taxId,
    required this.companyId,
    required this.taxCategory,
    required this.shortName,
    this.cgstRate = 0.0,
    this.sgstRate = 0.0,
    this.igstRate = 0.0,
    this.cessRate = 0.0,
    this.remarkOnInvoice = '',
    this.salesAccount,
    this.salesAccountOms,
    this.mouldAmortization,
    this.cgstAccount,
    this.sgstAccount,
    this.igstAccount,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalGstRate => cgstRate + sgstRate;

  factory TaxModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return TaxModel(
      taxId: id,
      companyId: (map['companyId'] ?? '') as String,
      taxCategory: (map['taxCategory'] ?? map['taxName'] ?? '') as String,
      shortName: (map['shortName'] ?? '') as String,
      cgstRate: parseDouble(map['cgstRate'] ?? map['cgst']),
      sgstRate: parseDouble(map['sgstRate'] ?? map['sgst']),
      igstRate: parseDouble(map['igstRate'] ?? map['igst']),
      cessRate: parseDouble(map['cessRate'] ?? map['cess']),
      remarkOnInvoice: (map['remarkOnInvoice'] ?? '') as String,
      salesAccount: map['salesAccount'] as String?,
      salesAccountOms: map['salesAccountOms'] as String?,
      mouldAmortization: map['mouldAmortization'] as String?,
      cgstAccount: map['cgstAccount'] as String?,
      sgstAccount: map['sgstAccount'] as String?,
      igstAccount: map['igstAccount'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'taxCategory': taxCategory.trim(),
      'taxName': taxCategory.trim(), // alias for compatibility
      'shortName': shortName.trim(),
      'cgstRate': cgstRate,
      'sgstRate': sgstRate,
      'igstRate': igstRate,
      'cessRate': cessRate,
      'remarkOnInvoice': remarkOnInvoice.trim(),
      'salesAccount': (salesAccount != null && salesAccount!.trim().isNotEmpty) ? salesAccount!.trim() : null,
      'salesAccountOms': (salesAccountOms != null && salesAccountOms!.trim().isNotEmpty) ? salesAccountOms!.trim() : null,
      'mouldAmortization': (mouldAmortization != null && mouldAmortization!.trim().isNotEmpty) ? mouldAmortization!.trim() : null,
      'cgstAccount': (cgstAccount != null && cgstAccount!.trim().isNotEmpty) ? cgstAccount!.trim() : null,
      'sgstAccount': (sgstAccount != null && sgstAccount!.trim().isNotEmpty) ? sgstAccount!.trim() : null,
      'igstAccount': (igstAccount != null && igstAccount!.trim().isNotEmpty) ? igstAccount!.trim() : null,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TaxModel copyWith({
    String? taxId,
    String? companyId,
    String? taxCategory,
    String? shortName,
    double? cgstRate,
    double? sgstRate,
    double? igstRate,
    double? cessRate,
    String? remarkOnInvoice,
    String? salesAccount,
    String? salesAccountOms,
    String? mouldAmortization,
    String? cgstAccount,
    String? sgstAccount,
    String? igstAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaxModel(
      taxId: taxId ?? this.taxId,
      companyId: companyId ?? this.companyId,
      taxCategory: taxCategory ?? this.taxCategory,
      shortName: shortName ?? this.shortName,
      cgstRate: cgstRate ?? this.cgstRate,
      sgstRate: sgstRate ?? this.sgstRate,
      igstRate: igstRate ?? this.igstRate,
      cessRate: cessRate ?? this.cessRate,
      remarkOnInvoice: remarkOnInvoice ?? this.remarkOnInvoice,
      salesAccount: salesAccount ?? this.salesAccount,
      salesAccountOms: salesAccountOms ?? this.salesAccountOms,
      mouldAmortization: mouldAmortization ?? this.mouldAmortization,
      cgstAccount: cgstAccount ?? this.cgstAccount,
      sgstAccount: sgstAccount ?? this.sgstAccount,
      igstAccount: igstAccount ?? this.igstAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
