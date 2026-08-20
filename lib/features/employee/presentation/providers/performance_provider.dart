import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/performance_history_model.dart';

class PerformanceStats {
  final double averageScore;
  final int completedTasks;
  final int earlyTasks;
  final int onTimeTasks;
  final int lateTasks;
  final double averageCompletionTimeMinutes;
  final int totalLateMinutes;

  PerformanceStats({
    required this.averageScore,
    required this.completedTasks,
    required this.earlyTasks,
    required this.onTimeTasks,
    required this.lateTasks,
    required this.averageCompletionTimeMinutes,
    required this.totalLateMinutes,
  });

  factory PerformanceStats.empty() {
    return PerformanceStats(
      averageScore: 0.0,
      completedTasks: 0,
      earlyTasks: 0,
      onTimeTasks: 0,
      lateTasks: 0,
      averageCompletionTimeMinutes: 0.0,
      totalLateMinutes: 0,
    );
  }

  factory PerformanceStats.calculate(List<PerformanceHistoryModel> history) {
    if (history.isEmpty) return PerformanceStats.empty();

    int totalScore = 0;
    int early = 0;
    int onTime = 0;
    int late = 0;
    int totalTime = 0;
    int totalLate = 0;

    for (final item in history) {
      totalScore += item.performanceScore;
      if (item.completionTiming == 'Early') {
        early++;
      } else if (item.completionTiming == 'On Time') {
        onTime++;
      } else if (item.completionTiming == 'Late') {
        late++;
      }
      totalTime += item.totalTimeTaken;
      totalLate += item.lateDuration;
    }

    return PerformanceStats(
      averageScore: totalScore / history.length,
      completedTasks: history.length,
      earlyTasks: early,
      onTimeTasks: onTime,
      lateTasks: late,
      averageCompletionTimeMinutes: totalTime / history.length,
      totalLateMinutes: totalLate,
    );
  }
}

// Stream of Performance History for an employee
final performanceHistoryStreamProvider = StreamProvider.family<List<PerformanceHistoryModel>, String>((ref, employeeId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('employees')
      .doc(employeeId)
      .collection('performanceHistory')
      .orderBy('actualCompletionTime', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => PerformanceHistoryModel.fromMap(doc.data(), doc.id)).toList();
      });
});

enum PerformanceFilter {
  daily,
  weekly,
  monthly,
  longTerm,
}

// Family provider to get filtered history
final filteredPerformanceHistoryProvider = Provider.family<List<PerformanceHistoryModel>, ({String employeeId, PerformanceFilter filter})>((ref, arg) {
  final historyAsync = ref.watch(performanceHistoryStreamProvider(arg.employeeId));
  final history = historyAsync.value ?? [];

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  return history.where((item) {
    if (item.actualCompletionTime == null) return false;
    final completionDate = item.actualCompletionTime!;

    switch (arg.filter) {
      case PerformanceFilter.daily:
        return completionDate.isAfter(todayStart);
      case PerformanceFilter.weekly:
        final startOfWeek = now.subtract(const Duration(days: 7));
        return completionDate.isAfter(startOfWeek);
      case PerformanceFilter.monthly:
        final startOfMonth = now.subtract(const Duration(days: 30));
        return completionDate.isAfter(startOfMonth);
      case PerformanceFilter.longTerm:
        return true;
    }
  }).toList();
});

// Family provider to calculate stats for a given filter
final performanceStatsProvider = Provider.family<PerformanceStats, ({String employeeId, PerformanceFilter filter})>((ref, arg) {
  final list = ref.watch(filteredPerformanceHistoryProvider(arg));
  return PerformanceStats.calculate(list);
});
