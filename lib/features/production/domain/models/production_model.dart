import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionModel {
  final String productionId;
  final String productName;
  final int quantity;
  final int completedQuantity;
  final int rejectedQuantity;
  final String assignedSupervisor; // Stores employeeId of the supervisor
  final List<String> assignedEmployees; // Stores list of employeeIds
  final DateTime productionDate;
  final String status; // Pending, In Progress, Completed, Cancelled
  final String remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields for tooling & drawings
  final List<String>? selectedToolIds;
  final List<String>? selectedToolNames;
  final String? drawingUrl;
  final String? drawingFileName;

  const ProductionModel({
    required this.productionId,
    required this.productName,
    required this.quantity,
    required this.completedQuantity,
    required this.rejectedQuantity,
    required this.assignedSupervisor,
    required this.assignedEmployees,
    required this.productionDate,
    required this.status,
    required this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.selectedToolIds,
    this.selectedToolNames,
    this.drawingUrl,
    this.drawingFileName,
  });

  factory ProductionModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return ProductionModel(
      productionId: id,
      productName: (map['productName'] ?? '') as String,
      quantity: (map['quantity'] ?? 0) as int,
      completedQuantity: (map['completedQuantity'] ?? 0) as int,
      rejectedQuantity: (map['rejectedQuantity'] ?? 0) as int,
      assignedSupervisor: (map['assignedSupervisor'] ?? '') as String,
      assignedEmployees: List<String>.from(map['assignedEmployees'] ?? []),
      productionDate: parseDate(map['productionDate']),
      status: (map['status'] ?? 'Pending') as String,
      remarks: (map['remarks'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      selectedToolIds: map['selectedToolIds'] != null ? List<String>.from(map['selectedToolIds']) : null,
      selectedToolNames: map['selectedToolNames'] != null ? List<String>.from(map['selectedToolNames']) : null,
      drawingUrl: map['drawingUrl'] as String?,
      drawingFileName: map['drawingFileName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productionId': productionId,
      'productName': productName,
      'quantity': quantity,
      'completedQuantity': completedQuantity,
      'rejectedQuantity': rejectedQuantity,
      'assignedSupervisor': assignedSupervisor,
      'assignedEmployees': assignedEmployees,
      'productionDate': Timestamp.fromDate(productionDate),
      'status': status,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'selectedToolIds': selectedToolIds,
      'selectedToolNames': selectedToolNames,
      'drawingUrl': drawingUrl,
      'drawingFileName': drawingFileName,
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

  ProductionModel copyWith({
    String? productionId,
    String? productName,
    int? quantity,
    int? completedQuantity,
    int? rejectedQuantity,
    String? assignedSupervisor,
    List<String>? assignedEmployees,
    DateTime? productionDate,
    String? status,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? selectedToolIds,
    List<String>? selectedToolNames,
    String? drawingUrl,
    String? drawingFileName,
  }) {
    return ProductionModel(
      productionId: productionId ?? this.productionId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      completedQuantity: completedQuantity ?? this.completedQuantity,
      rejectedQuantity: rejectedQuantity ?? this.rejectedQuantity,
      assignedSupervisor: assignedSupervisor ?? this.assignedSupervisor,
      assignedEmployees: assignedEmployees ?? this.assignedEmployees,
      productionDate: productionDate ?? this.productionDate,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      selectedToolIds: selectedToolIds ?? this.selectedToolIds,
      selectedToolNames: selectedToolNames ?? this.selectedToolNames,
      drawingUrl: drawingUrl ?? this.drawingUrl,
      drawingFileName: drawingFileName ?? this.drawingFileName,
    );
  }
}
