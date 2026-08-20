import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceHistoryModel {
  final String taskId;
  final String taskName;
  final String machine;
  final String department;
  final DateTime assignedDate;
  final DateTime? startDate;
  final DateTime? estimatedCompletionTime;
  final int allowedTime;
  final DateTime? actualCompletionTime;
  final int totalTimeTaken;
  final String completionTiming; // Early, On Time, Late
  final int lateDuration;
  final String lateReason;
  final List<String> selectedTooling;
  final String performanceRating;
  final int performanceScore;

  const PerformanceHistoryModel({
    required this.taskId,
    required this.taskName,
    required this.machine,
    required this.department,
    required this.assignedDate,
    this.startDate,
    this.estimatedCompletionTime,
    required this.allowedTime,
    this.actualCompletionTime,
    required this.totalTimeTaken,
    required this.completionTiming,
    required this.lateDuration,
    required this.lateReason,
    required this.selectedTooling,
    required this.performanceRating,
    required this.performanceScore,
  });

  factory PerformanceHistoryModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return PerformanceHistoryModel(
      taskId: docId,
      taskName: (map['taskName'] ?? '') as String,
      machine: (map['machine'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      assignedDate: parseDate(map['assignedDate']),
      startDate: parseDateNullable(map['startDate']),
      estimatedCompletionTime: parseDateNullable(map['estimatedCompletionTime']),
      allowedTime: (map['allowedTime'] ?? 0) as int,
      actualCompletionTime: parseDateNullable(map['actualCompletionTime']),
      totalTimeTaken: (map['totalTimeTaken'] ?? 0) as int,
      completionTiming: (map['completionTiming'] ?? 'On Time') as String,
      lateDuration: (map['lateDuration'] ?? 0) as int,
      lateReason: (map['lateReason'] ?? '') as String,
      selectedTooling: List<String>.from(map['selectedTooling'] ?? []),
      performanceRating: (map['performanceRating'] ?? '') as String,
      performanceScore: (map['performanceScore'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'taskName': taskName,
      'machine': machine,
      'department': department,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'estimatedCompletionTime': estimatedCompletionTime != null ? Timestamp.fromDate(estimatedCompletionTime!) : null,
      'allowedTime': allowedTime,
      'actualCompletionTime': actualCompletionTime != null ? Timestamp.fromDate(actualCompletionTime!) : null,
      'totalTimeTaken': totalTimeTaken,
      'completionTiming': completionTiming,
      'lateDuration': lateDuration,
      'lateReason': lateReason,
      'selectedTooling': selectedTooling,
      'performanceRating': performanceRating,
      'performanceScore': performanceScore,
    };
  }
}
