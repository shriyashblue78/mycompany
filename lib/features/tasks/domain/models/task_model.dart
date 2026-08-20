import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String taskId;
  final String companyId;
  final String title;
  final String description;
  final String assignedToEmployeeId;
  final String assignedToUid;
  final String assignedBy;
  final String priority; // Low, Medium, High, Critical
  final String status; // Pending, In Progress, Completed, Cancelled, On Hold
  final String department;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime? completedDate;
  final double progress; // 0.0 to 100.0
  final List<String> attachments;
  final List<String> remarks;
  
  // Machine Data
  final String? machineId;
  final String? machineName;
  final String? machineCode;

  // Program Data
  final String? programId;
  final String? programName;

  // Drawing Photo
  final String? drawingPhotoUrl;

  // Assignee Additions
  final String? assignedToName;

  // Rejection Metadata
  final String? rejectedByUid;
  final String? rejectedByName;
  final DateTime? rejectedAt;
  final String? rejectionReason;

  // Tooling & Duration fields
  final int? estimatedDurationMinutes;
  final bool? toolingRequired;
  final List<String>? selectedToolIds;
  final List<String>? selectedToolNames;
  final String? toolingRemark;

  // Additional Timing & Countdown fields
  final DateTime? taskStartTime;
  final int? bufferMinutes;
  final int? allowedDurationMinutes;
  final DateTime? deadlineTime;
  final DateTime? actualCompletionTime;
  final int? totalTimeTakenMinutes;
  final String? completionTiming; // Early, On Time, Late
  final int? lateDurationMinutes;
  final String? lateReason;
  final int? performanceScore;
  final String? performanceRating;

  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.taskId,
    required this.companyId,
    required this.title,
    required this.description,
    required this.assignedToEmployeeId,
    required this.assignedToUid,
    required this.assignedBy,
    required this.priority,
    required this.status,
    required this.department,
    required this.startDate,
    required this.dueDate,
    this.completedDate,
    required this.progress,
    required this.attachments,
    required this.remarks,
    this.machineId,
    this.machineName,
    this.machineCode,
    this.programId,
    this.programName,
    this.drawingPhotoUrl,
    this.assignedToName,
    this.rejectedByUid,
    this.rejectedByName,
    this.rejectedAt,
    this.rejectionReason,
    this.estimatedDurationMinutes,
    this.toolingRequired,
    this.selectedToolIds,
    this.selectedToolNames,
    this.toolingRemark,
    this.taskStartTime,
    this.bufferMinutes,
    this.allowedDurationMinutes,
    this.deadlineTime,
    this.actualCompletionTime,
    this.totalTimeTakenMinutes,
    this.completionTiming,
    this.lateDurationMinutes,
    this.lateReason,
    this.performanceScore,
    this.performanceRating,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return TaskModel(
      taskId: id,
      companyId: (map['companyId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      assignedToEmployeeId: (map['assignedToEmployeeId'] ?? '') as String,
      assignedToUid: (map['assignedToUid'] ?? '') as String,
      assignedBy: (map['assignedBy'] ?? '') as String,
      priority: (map['priority'] ?? 'Low') as String,
      status: (map['status'] ?? 'Pending') as String,
      department: (map['department'] ?? '') as String,
      startDate: parseDate(map['startDate']),
      dueDate: parseDate(map['dueDate']),
      completedDate: parseDateNullable(map['completedDate']),
      progress: (map['progress'] ?? 0.0) is int
          ? ((map['progress'] ?? 0) as int).toDouble()
          : (map['progress'] ?? 0.0) as double,
      attachments: List<String>.from(map['attachments'] ?? []),
      remarks: List<String>.from(map['remarks'] ?? []),
      machineId: map['machineId'] as String?,
      machineName: map['machineName'] as String?,
      machineCode: map['machineCode'] as String?,
      programId: map['programId'] as String?,
      programName: map['programName'] as String?,
      drawingPhotoUrl: map['drawingPhotoUrl'] as String?,
      assignedToName: map['assignedToName'] as String?,
      rejectedByUid: map['rejectedByUid'] as String?,
      rejectedByName: map['rejectedByName'] as String?,
      rejectedAt: parseDateNullable(map['rejectedAt']),
      rejectionReason: map['rejectionReason'] as String?,
      estimatedDurationMinutes: map['estimatedDurationMinutes'] as int?,
      toolingRequired: map['toolingRequired'] as bool?,
      selectedToolIds: map['selectedToolIds'] != null ? List<String>.from(map['selectedToolIds']) : null,
      selectedToolNames: map['selectedToolNames'] != null ? List<String>.from(map['selectedToolNames']) : null,
      toolingRemark: map['toolingRemark'] as String?,
      taskStartTime: parseDateNullable(map['taskStartTime']),
      bufferMinutes: map['bufferMinutes'] as int?,
      allowedDurationMinutes: map['allowedDurationMinutes'] as int?,
      deadlineTime: parseDateNullable(map['deadlineTime']),
      actualCompletionTime: parseDateNullable(map['actualCompletionTime']),
      totalTimeTakenMinutes: map['totalTimeTakenMinutes'] as int?,
      completionTiming: map['completionTiming'] as String?,
      lateDurationMinutes: map['lateDurationMinutes'] as int?,
      lateReason: map['lateReason'] as String?,
      performanceScore: map['performanceScore'] != null
          ? (map['performanceScore'] as num).toInt()
          : null,
      performanceRating: map['performanceRating'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'companyId': companyId,
      'title': title,
      'description': description,
      'assignedToEmployeeId': assignedToEmployeeId,
      'assignedToUid': assignedToUid,
      'assignedBy': assignedBy,
      'priority': priority,
      'status': status,
      'department': department,
      'startDate': Timestamp.fromDate(startDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'progress': progress,
      'attachments': attachments,
      'remarks': remarks,
      'machineId': machineId,
      'machineName': machineName,
      'machineCode': machineCode,
      'programId': programId,
      'programName': programName,
      'drawingPhotoUrl': drawingPhotoUrl,
      'assignedToName': assignedToName,
      'rejectedByUid': rejectedByUid,
      'rejectedByName': rejectedByName,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectionReason': rejectionReason,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'toolingRequired': toolingRequired,
      'selectedToolIds': selectedToolIds,
      'selectedToolNames': selectedToolNames,
      'toolingRemark': toolingRemark,
      'taskStartTime': taskStartTime != null ? Timestamp.fromDate(taskStartTime!) : null,
      'bufferMinutes': bufferMinutes,
      'allowedDurationMinutes': allowedDurationMinutes,
      'deadlineTime': deadlineTime != null ? Timestamp.fromDate(deadlineTime!) : null,
      'actualCompletionTime': actualCompletionTime != null ? Timestamp.fromDate(actualCompletionTime!) : null,
      'totalTimeTakenMinutes': totalTimeTakenMinutes,
      'completionTiming': completionTiming,
      'lateDurationMinutes': lateDurationMinutes,
      'lateReason': lateReason,
      'performanceScore': performanceScore,
      'performanceRating': performanceRating,
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

  TaskModel copyWith({
    String? taskId,
    String? companyId,
    String? title,
    String? description,
    String? assignedToEmployeeId,
    String? assignedToUid,
    String? assignedBy,
    String? priority,
    String? status,
    String? department,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedDate,
    double? progress,
    List<String>? attachments,
    List<String>? remarks,
    String? machineId,
    String? machineName,
    String? machineCode,
    String? programId,
    String? programName,
    String? drawingPhotoUrl,
    String? assignedToName,
    String? rejectedByUid,
    String? rejectedByName,
    DateTime? rejectedAt,
    String? rejectionReason,
    int? estimatedDurationMinutes,
    bool? toolingRequired,
    List<String>? selectedToolIds,
    List<String>? selectedToolNames,
    String? toolingRemark,
    DateTime? taskStartTime,
    int? bufferMinutes,
    int? allowedDurationMinutes,
    DateTime? deadlineTime,
    DateTime? actualCompletionTime,
    int? totalTimeTakenMinutes,
    String? completionTiming,
    int? lateDurationMinutes,
    String? lateReason,
    int? performanceScore,
    String? performanceRating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      taskId: taskId ?? this.taskId,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedToEmployeeId: assignedToEmployeeId ?? this.assignedToEmployeeId,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      assignedBy: assignedBy ?? this.assignedBy,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      department: department ?? this.department,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      completedDate: completedDate ?? this.completedDate,
      progress: progress ?? this.progress,
      attachments: attachments ?? this.attachments,
      remarks: remarks ?? this.remarks,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      machineCode: machineCode ?? this.machineCode,
      programId: programId ?? this.programId,
      programName: programName ?? this.programName,
      drawingPhotoUrl: drawingPhotoUrl ?? this.drawingPhotoUrl,
      assignedToName: assignedToName ?? this.assignedToName,
      rejectedByUid: rejectedByUid ?? this.rejectedByUid,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      toolingRequired: toolingRequired ?? this.toolingRequired,
      selectedToolIds: selectedToolIds ?? this.selectedToolIds,
      selectedToolNames: selectedToolNames ?? this.selectedToolNames,
      toolingRemark: toolingRemark ?? this.toolingRemark,
      taskStartTime: taskStartTime ?? this.taskStartTime,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      allowedDurationMinutes: allowedDurationMinutes ?? this.allowedDurationMinutes,
      deadlineTime: deadlineTime ?? this.deadlineTime,
      actualCompletionTime: actualCompletionTime ?? this.actualCompletionTime,
      totalTimeTakenMinutes: totalTimeTakenMinutes ?? this.totalTimeTakenMinutes,
      completionTiming: completionTiming ?? this.completionTiming,
      lateDurationMinutes: lateDurationMinutes ?? this.lateDurationMinutes,
      lateReason: lateReason ?? this.lateReason,
      performanceScore: performanceScore ?? this.performanceScore,
      performanceRating: performanceRating ?? this.performanceRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
