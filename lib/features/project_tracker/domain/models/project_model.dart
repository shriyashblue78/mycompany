import 'package:cloud_firestore/cloud_firestore.dart';

class StageHistoryEntry {
  final String department;
  final String status;
  final String responsiblePerson;
  final DateTime timestamp;
  final String remarks;

  const StageHistoryEntry({
    required this.department,
    required this.status,
    required this.responsiblePerson,
    required this.timestamp,
    required this.remarks,
  });

  factory StageHistoryEntry.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }
    return StageHistoryEntry(
      department: (map['department'] ?? '') as String,
      status: (map['status'] ?? '') as String,
      responsiblePerson: (map['responsiblePerson'] ?? '') as String,
      timestamp: parseDate(map['timestamp']),
      remarks: (map['remarks'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'department': department,
      'status': status,
      'responsiblePerson': responsiblePerson,
      'timestamp': Timestamp.fromDate(timestamp),
      'remarks': remarks,
    };
  }
}

class ProjectStage {
  final String status; // 'Pending', 'In Progress', 'Completed'
  final DateTime? completedAt;
  final String? assignedUser;

  const ProjectStage({
    required this.status,
    this.completedAt,
    this.assignedUser,
  });

  factory ProjectStage.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }
    return ProjectStage(
      status: (map['status'] ?? 'Pending') as String,
      completedAt: parseDate(map['completedAt']),
      assignedUser: map['assignedUser'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'assignedUser': assignedUser,
    };
  }

  ProjectStage copyWith({
    String? status,
    DateTime? completedAt,
    String? assignedUser,
  }) {
    return ProjectStage(
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      assignedUser: assignedUser ?? this.assignedUser,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectStage &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          completedAt == other.completedAt &&
          assignedUser == other.assignedUser;

  @override
  int get hashCode => status.hashCode ^ completedAt.hashCode ^ assignedUser.hashCode;
}

class ProjectModel {
  final String projectId;
  final String companyId;
  final String projectName;
  final String description;
  final String status; // 'Planned', 'In Progress', 'Completed', 'On Hold'
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Stages
  final ProjectStage marketingStage;
  final ProjectStage designStage;
  final ProjectStage purchaseStage;
  final ProjectStage machiningStage;
  final ProjectStage assemblyStage;
  final ProjectStage qualityStage;
  final ProjectStage accountsStage;

  // Relay details
  final String currentStage; // 'Marketing', 'Design', ..., 'Completed'
  final List<StageHistoryEntry> stageHistory;

  const ProjectModel({
    required this.projectId,
    required this.companyId,
    required this.projectName,
    required this.description,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.marketingStage = const ProjectStage(status: 'Pending'),
    this.designStage = const ProjectStage(status: 'Pending'),
    this.purchaseStage = const ProjectStage(status: 'Pending'),
    this.machiningStage = const ProjectStage(status: 'Pending'),
    this.assemblyStage = const ProjectStage(status: 'Pending'),
    this.qualityStage = const ProjectStage(status: 'Pending'),
    this.accountsStage = const ProjectStage(status: 'Pending'),
    this.currentStage = 'Marketing',
    this.stageHistory = const [],
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final historyRaw = map['stageHistory'] as List<dynamic>? ?? [];
    final historyList = historyRaw
        .map((h) => StageHistoryEntry.fromMap(Map<String, dynamic>.from(h)))
        .toList();

    return ProjectModel(
      projectId: docId,
      companyId: (map['companyId'] ?? '') as String,
      projectName: (map['projectName'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      status: (map['status'] ?? 'Planned') as String,
      startDate: parseDate(map['startDate']),
      endDate: map['endDate'] != null ? parseDate(map['endDate']) : null,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      marketingStage: map['marketingStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['marketingStage']))
          : const ProjectStage(status: 'Pending'),
      designStage: map['designStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['designStage']))
          : const ProjectStage(status: 'Pending'),
      purchaseStage: map['purchaseStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['purchaseStage']))
          : const ProjectStage(status: 'Pending'),
      machiningStage: map['machiningStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['machiningStage']))
          : const ProjectStage(status: 'Pending'),
      assemblyStage: map['assemblyStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['assemblyStage']))
          : const ProjectStage(status: 'Pending'),
      qualityStage: map['qualityStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['qualityStage']))
          : const ProjectStage(status: 'Pending'),
      accountsStage: map['accountsStage'] != null
          ? ProjectStage.fromMap(Map<String, dynamic>.from(map['accountsStage']))
          : const ProjectStage(status: 'Pending'),
      currentStage: (map['currentStage'] ?? 'Marketing') as String,
      stageHistory: historyList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'projectName': projectName,
      'description': description,
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'marketingStage': marketingStage.toMap(),
      'designStage': designStage.toMap(),
      'purchaseStage': purchaseStage.toMap(),
      'machiningStage': machiningStage.toMap(),
      'assemblyStage': assemblyStage.toMap(),
      'qualityStage': qualityStage.toMap(),
      'accountsStage': accountsStage.toMap(),
      'currentStage': currentStage,
      'stageHistory': stageHistory.map((h) => h.toMap()).toList(),
    };
  }

  ProjectModel copyWith({
    String? projectId,
    String? companyId,
    String? projectName,
    String? description,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectStage? marketingStage,
    ProjectStage? designStage,
    ProjectStage? purchaseStage,
    ProjectStage? machiningStage,
    ProjectStage? assemblyStage,
    ProjectStage? qualityStage,
    ProjectStage? accountsStage,
    String? currentStage,
    List<StageHistoryEntry>? stageHistory,
  }) {
    return ProjectModel(
      projectId: projectId ?? this.projectId,
      companyId: companyId ?? this.companyId,
      projectName: projectName ?? this.projectName,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      marketingStage: marketingStage ?? this.marketingStage,
      designStage: designStage ?? this.designStage,
      purchaseStage: purchaseStage ?? this.purchaseStage,
      machiningStage: machiningStage ?? this.machiningStage,
      assemblyStage: assemblyStage ?? this.assemblyStage,
      qualityStage: qualityStage ?? this.qualityStage,
      accountsStage: accountsStage ?? this.accountsStage,
      currentStage: currentStage ?? this.currentStage,
      stageHistory: stageHistory ?? this.stageHistory,
    );
  }
}
