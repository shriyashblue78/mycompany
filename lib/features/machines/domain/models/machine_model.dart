import 'package:cloud_firestore/cloud_firestore.dart';

class MachineModel {
  final String machineId;
  final String companyId;
  final String machineName;
  final String machineCode;
  final String machineType;
  final String location;
  final String status; // Active, Inactive, Under Maintenance
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MachineModel({
    required this.machineId,
    required this.companyId,
    required this.machineName,
    required this.machineCode,
    required this.machineType,
    required this.location,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MachineModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return MachineModel(
      machineId: id,
      companyId: (map['companyId'] ?? '') as String,
      machineName: (map['machineName'] ?? '') as String,
      machineCode: (map['machineCode'] ?? '') as String,
      machineType: (map['machineType'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      status: (map['status'] ?? 'Active') as String,
      description: (map['description'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'machineId': machineId,
      'companyId': companyId,
      'machineName': machineName,
      'machineCode': machineCode,
      'machineType': machineType,
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

  MachineModel copyWith({
    String? machineId,
    String? companyId,
    String? machineName,
    String? machineCode,
    String? machineType,
    String? location,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MachineModel(
      machineId: machineId ?? this.machineId,
      companyId: companyId ?? this.companyId,
      machineName: machineName ?? this.machineName,
      machineCode: machineCode ?? this.machineCode,
      machineType: machineType ?? this.machineType,
      location: location ?? this.location,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
