import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String itemId;
  final String companyId;
  final String itemNo; // unique item/part number
  final String itemDescription; // Item Name / Description
  final String category; // from Category Master
  final String? underGroup; // from Group Master
  final String? drawingNo;
  final String? previousNo;
  final String stockUnit; // from Unit Master
  final String? hsnSac;
  final double unitRate;
  final double finishRate;
  final double netWeight;
  final String? storeLocation;
  final double minimumLevel;
  final bool isFinishedItem;
  final String? materialSpecification;
  final double qtyPerPack;
  final double openingBalance;
  final String? storeOrWip;
  final bool hasOpeningBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemModel({
    required this.itemId,
    required this.companyId,
    required this.itemNo,
    required this.itemDescription,
    required this.category,
    this.underGroup,
    this.drawingNo,
    this.previousNo,
    required this.stockUnit,
    this.hsnSac,
    this.unitRate = 0.0,
    this.finishRate = 0.0,
    this.netWeight = 0.0,
    this.storeLocation,
    this.minimumLevel = 0.0,
    this.isFinishedItem = false,
    this.materialSpecification,
    this.qtyPerPack = 1.0,
    this.openingBalance = 0.0,
    this.storeOrWip,
    this.hasOpeningBalance = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map, String id) {
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

    // Support both new field names and inventory legacy field names
    final itemNum = (map['itemNo'] ?? map['partNumber'] ?? '') as String;
    final itemDesc = (map['itemDescription'] ?? map['itemName'] ?? '') as String;

    return ItemModel(
      itemId: id,
      companyId: (map['companyId'] ?? '') as String,
      itemNo: itemNum,
      itemDescription: itemDesc,
      category: (map['category'] ?? 'General') as String,
      underGroup: map['underGroup'] as String? ?? map['group'] as String?,
      drawingNo: map['drawingNo'] as String?,
      previousNo: map['previousNo'] as String?,
      stockUnit: (map['stockUnit'] ?? map['unit'] ?? 'Nos') as String,
      hsnSac: map['hsnSac'] as String?,
      unitRate: parseDouble(map['unitRate'] ?? map['price']),
      finishRate: parseDouble(map['finishRate']),
      netWeight: parseDouble(map['netWeight']),
      storeLocation: map['storeLocation'] as String?,
      minimumLevel: parseDouble(map['minimumLevel']),
      isFinishedItem: (map['isFinishedItem'] ?? false) as bool,
      materialSpecification: map['materialSpecification'] as String?,
      qtyPerPack: parseDouble(map['qtyPerPack'] ?? 1.0),
      openingBalance: parseDouble(map['openingBalance'] ?? map['openingStock']),
      storeOrWip: map['storeOrWip'] as String? ?? map['storeLocation'] as String?,
      hasOpeningBalance: (map['hasOpeningBalance'] ?? map['openingBalanceEntered'] ?? ((map['openingBalance'] ?? 0) > 0)) as bool,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'itemNo': itemNo.trim(),
      'itemDescription': itemDescription.trim(),
      // Legacy compatibility keys for existing inventory widgets
      'partNumber': itemNo.trim(),
      'itemName': itemDescription.trim(),
      'category': category.trim(),
      'underGroup': (underGroup != null && underGroup!.trim().isNotEmpty) ? underGroup!.trim() : null,
      'group': (underGroup != null && underGroup!.trim().isNotEmpty) ? underGroup!.trim() : null,
      'drawingNo': (drawingNo != null && drawingNo!.trim().isNotEmpty) ? drawingNo!.trim() : null,
      'previousNo': (previousNo != null && previousNo!.trim().isNotEmpty) ? previousNo!.trim() : null,
      'stockUnit': stockUnit.trim(),
      'unit': stockUnit.trim(),
      'hsnSac': (hsnSac != null && hsnSac!.trim().isNotEmpty) ? hsnSac!.trim() : null,
      'unitRate': unitRate,
      'finishRate': finishRate,
      'netWeight': netWeight,
      'storeLocation': (storeLocation != null && storeLocation!.trim().isNotEmpty) ? storeLocation!.trim() : null,
      'minimumLevel': minimumLevel,
      'isFinishedItem': isFinishedItem,
      'materialSpecification': (materialSpecification != null && materialSpecification!.trim().isNotEmpty) ? materialSpecification!.trim() : null,
      'qtyPerPack': qtyPerPack,
      'openingBalance': openingBalance,
      'storeOrWip': storeOrWip,
      'hasOpeningBalance': hasOpeningBalance,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ItemModel copyWith({
    String? itemId,
    String? companyId,
    String? itemNo,
    String? itemDescription,
    String? category,
    String? underGroup,
    String? drawingNo,
    String? previousNo,
    String? stockUnit,
    String? hsnSac,
    double? unitRate,
    double? finishRate,
    double? netWeight,
    String? storeLocation,
    double? minimumLevel,
    bool? isFinishedItem,
    String? materialSpecification,
    double? qtyPerPack,
    double? openingBalance,
    String? storeOrWip,
    bool? hasOpeningBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      itemId: itemId ?? this.itemId,
      companyId: companyId ?? this.companyId,
      itemNo: itemNo ?? this.itemNo,
      itemDescription: itemDescription ?? this.itemDescription,
      category: category ?? this.category,
      underGroup: underGroup ?? this.underGroup,
      drawingNo: drawingNo ?? this.drawingNo,
      previousNo: previousNo ?? this.previousNo,
      stockUnit: stockUnit ?? this.stockUnit,
      hsnSac: hsnSac ?? this.hsnSac,
      unitRate: unitRate ?? this.unitRate,
      finishRate: finishRate ?? this.finishRate,
      netWeight: netWeight ?? this.netWeight,
      storeLocation: storeLocation ?? this.storeLocation,
      minimumLevel: minimumLevel ?? this.minimumLevel,
      isFinishedItem: isFinishedItem ?? this.isFinishedItem,
      materialSpecification: materialSpecification ?? this.materialSpecification,
      qtyPerPack: qtyPerPack ?? this.qtyPerPack,
      openingBalance: openingBalance ?? this.openingBalance,
      storeOrWip: storeOrWip ?? this.storeOrWip,
      hasOpeningBalance: hasOpeningBalance ?? this.hasOpeningBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
