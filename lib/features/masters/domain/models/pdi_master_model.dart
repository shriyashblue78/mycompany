import 'package:cloud_firestore/cloud_firestore.dart';

class PdiMasterModel {
  final String pdiId;
  final String companyId;
  final String itemName;
  final String partNo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PdiMasterModel({
    required this.pdiId,
    required this.companyId,
    required this.itemName,
    required this.partNo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PdiMasterModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return PdiMasterModel(
      pdiId: id,
      companyId: (map['companyId'] ?? '') as String,
      itemName: (map['itemName'] ?? '') as String,
      partNo: (map['partNo'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'itemName': itemName.trim(),
      'partNo': partNo.trim(),
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PdiMasterModel copyWith({
    String? pdiId,
    String? companyId,
    String? itemName,
    String? partNo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PdiMasterModel(
      pdiId: pdiId ?? this.pdiId,
      companyId: companyId ?? this.companyId,
      itemName: itemName ?? this.itemName,
      partNo: partNo ?? this.partNo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
