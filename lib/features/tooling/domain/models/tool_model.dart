import 'package:cloud_firestore/cloud_firestore.dart';

class ToolModel {
  final String toolId;
  final String companyId;
  final String toolName;
  final String toolCode;
  final String toolType;
  final String location;
  final String status; // Active, Inactive
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ToolModel({
    required this.toolId,
    required this.companyId,
    required this.toolName,
    required this.toolCode,
    required this.toolType,
    required this.location,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ToolModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return ToolModel(
      toolId: id,
      companyId: (map['companyId'] ?? '') as String,
      toolName: (map['toolName'] ?? '') as String,
      toolCode: (map['toolCode'] ?? '') as String,
      toolType: (map['toolType'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      status: (map['status'] ?? 'Active') as String,
      description: (map['description'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toolId': toolId,
      'companyId': companyId,
      'toolName': toolName,
      'toolCode': toolCode,
      'toolType': toolType,
      'location': location,
      'status': status,
      'description': description,
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

  ToolModel copyWith({
    String? toolId,
    String? companyId,
    String? toolName,
    String? toolCode,
    String? toolType,
    String? location,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ToolModel(
      toolId: toolId ?? this.toolId,
      companyId: companyId ?? this.companyId,
      toolName: toolName ?? this.toolName,
      toolCode: toolCode ?? this.toolCode,
      toolType: toolType ?? this.toolType,
      location: location ?? this.location,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
