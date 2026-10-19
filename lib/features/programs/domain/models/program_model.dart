import 'package:cloud_firestore/cloud_firestore.dart';

class ProgramModel {
  final String programId;
  final String companyId;
  final String machineId;
  final String machineName;
  final String programName; // e.g., 001, 234, 5-6
  final List<String> imageUrls;
  final List<String> pdfUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProgramModel({
    required this.programId,
    required this.companyId,
    required this.machineId,
    required this.machineName,
    required this.programName,
    this.imageUrls = const [],
    this.pdfUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProgramModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return ProgramModel(
      programId: id,
      companyId: (map['companyId'] ?? '') as String,
      machineId: (map['machineId'] ?? '') as String,
      machineName: (map['machineName'] ?? '') as String,
      programName: (map['programName'] ?? '') as String,
      imageUrls: parseStringList(map['imageUrls']),
      pdfUrls: parseStringList(map['pdfUrls']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'companyId': companyId,
      'machineId': machineId,
      'machineName': machineName,
      'programName': programName,
      'imageUrls': imageUrls,
      'pdfUrls': pdfUrls,
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

  ProgramModel copyWith({
    String? programId,
    String? companyId,
    String? machineId,
    String? machineName,
    String? programName,
    List<String>? imageUrls,
    List<String>? pdfUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProgramModel(
      programId: programId ?? this.programId,
      companyId: companyId ?? this.companyId,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      programName: programName ?? this.programName,
      imageUrls: imageUrls ?? this.imageUrls,
      pdfUrls: pdfUrls ?? this.pdfUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
