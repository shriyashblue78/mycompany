import 'package:cloud_firestore/cloud_firestore.dart';

class InwardOutwardModel {
  final String id;
  final String companyId;
  final String direction; // 'Inward' or 'Outward'
  final String companyName;
  final String partNumber;
  final String partName;
  final String challanNumber;
  final DateTime date;
  final double quantity;
  final String quantityUnit; // 'Numbers/Pieces', 'Kilograms (kg)', 'Tons'
  final List<String> challanPhotoUrls;
  final List<String> materialPhotoUrls;
  final DateTime createdAt;
  final String createdByUid;
  final String createdByName;

  String? get challanPhotoUrl => challanPhotoUrls.isNotEmpty ? challanPhotoUrls.first : null;

  const InwardOutwardModel({
    required this.id,
    required this.companyId,
    required this.direction,
    required this.companyName,
    required this.partNumber,
    required this.partName,
    required this.challanNumber,
    required this.date,
    required this.quantity,
    required this.quantityUnit,
    this.challanPhotoUrls = const [],
    required this.materialPhotoUrls,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'direction': direction,
      'companyName': companyName,
      'partNumber': partNumber,
      'partName': partName,
      'challanNumber': challanNumber,
      'date': Timestamp.fromDate(date),
      'quantity': quantity,
      'quantityUnit': quantityUnit,
      'challanPhotoUrl': challanPhotoUrl,
      'challanPhotoUrls': challanPhotoUrls,
      'materialPhotoUrls': materialPhotoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }

  factory InwardOutwardModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final List<String> challanUrls = List<String>.from(map['challanPhotoUrls'] ?? []);
    if (challanUrls.isEmpty && map['challanPhotoUrl'] != null && (map['challanPhotoUrl'] as String).isNotEmpty) {
      challanUrls.add(map['challanPhotoUrl'] as String);
    }

    return InwardOutwardModel(
      id: documentId,
      companyId: map['companyId'] ?? '',
      direction: map['direction'] ?? 'Inward',
      companyName: map['companyName'] ?? '',
      partNumber: map['partNumber'] ?? '',
      partName: map['partName'] ?? '',
      challanNumber: map['challanNumber'] ?? '',
      date: parseDate(map['date']),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: map['quantityUnit'] ?? 'Numbers/Pieces',
      challanPhotoUrls: challanUrls,
      materialPhotoUrls: List<String>.from(map['materialPhotoUrls'] ?? []),
      createdAt: parseDate(map['createdAt']),
      createdByUid: map['createdByUid'] ?? '',
      createdByName: map['createdByName'] ?? '',
    );
  }

  InwardOutwardModel copyWith({
    String? id,
    String? companyId,
    String? direction,
    String? companyName,
    String? partNumber,
    String? partName,
    String? challanNumber,
    DateTime? date,
    double? quantity,
    String? quantityUnit,
    List<String>? challanPhotoUrls,
    List<String>? materialPhotoUrls,
    DateTime? createdAt,
    String? createdByUid,
    String? createdByName,
  }) {
    return InwardOutwardModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      direction: direction ?? this.direction,
      companyName: companyName ?? this.companyName,
      partNumber: partNumber ?? this.partNumber,
      partName: partName ?? this.partName,
      challanNumber: challanNumber ?? this.challanNumber,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      challanPhotoUrls: challanPhotoUrls ?? this.challanPhotoUrls,
      materialPhotoUrls: materialPhotoUrls ?? this.materialPhotoUrls,
      createdAt: createdAt ?? this.createdAt,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
