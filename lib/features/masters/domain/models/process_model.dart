import 'package:cloud_firestore/cloud_firestore.dart';

class ProcessModel {
  final String processId;
  final String companyId;
  final String processName;
  final String? sac; // Service Accounting Code
  final bool isAssyProcess; // Assembly Process?
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProcessModel({
    required this.processId,
    required this.companyId,
    required this.processName,
    this.sac,
    this.isAssyProcess = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProcessModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return ProcessModel(
      processId: id,
      companyId: (map['companyId'] ?? '') as String,
      processName: (map['processName'] ?? '') as String,
      sac: map['sac'] as String?,
      isAssyProcess: (map['isAssyProcess'] ?? false) as bool,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'processName': processName.trim(),
      'sac': (sac != null && sac!.trim().isNotEmpty) ? sac!.trim() : null,
      'isAssyProcess': isAssyProcess,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProcessModel copyWith({
    String? processId,
    String? companyId,
    String? processName,
    String? sac,
    bool? isAssyProcess,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcessModel(
      processId: processId ?? this.processId,
      companyId: companyId ?? this.companyId,
      processName: processName ?? this.processName,
      sac: sac ?? this.sac,
      isAssyProcess: isAssyProcess ?? this.isAssyProcess,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
