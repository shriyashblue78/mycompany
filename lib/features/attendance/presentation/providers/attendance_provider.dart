import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/attendance_model.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';

// Repository Provider
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl();
});

// Helper for formatted today's date (yyyy-MM-dd)
final todayDateStringProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

// Stream of today's attendance for the logged-in user
final todayAttendanceStreamProvider = StreamProvider<AttendanceModel?>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  final employeeId = authState.user?.employeeId;

  if (companyId == null || employeeId == null) {
    return Stream.value(null);
  }

  final todayStr = ref.watch(todayDateStringProvider);
  final repository = ref.watch(attendanceRepositoryProvider);
  return repository.streamTodayAttendance(companyId, employeeId, todayStr);
});

// Stream of a specific employee's attendance history
final employeeAttendanceHistoryProvider = StreamProvider.family<List<AttendanceModel>, String>((ref, employeeId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;

  if (companyId == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(attendanceRepositoryProvider);
  return repository.streamEmployeeAttendance(companyId, employeeId);
});

// Stream of all attendance records for the company
final companyAttendanceStreamProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;

  if (companyId == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(attendanceRepositoryProvider);
  return repository.streamCompanyAttendance(companyId);
});

// Stream of all active employees in the company (without page limits, for joins)
final allActiveEmployeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;

  if (companyId == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(employeeRepositoryProvider);
  // Fetch employees stream. Without a limit, it fetches all employees for the company.
  return repository.streamEmployees(companyId);
});

// Holds stats for a specific day
class AttendanceStats {
  final int totalEmployees;
  final int present;
  final int absent;
  final int lateCount;
  final int onLeave;

  AttendanceStats({
    required this.totalEmployees,
    required this.present,
    required this.absent,
    required this.lateCount,
    required this.onLeave,
  });
}

// Provider for today's attendance stats (Owner/HR/Supervisor overview)
final todayAttendanceStatsProvider = Provider<AsyncValue<AttendanceStats>>((ref) {
  final employeesAsync = ref.watch(allActiveEmployeesProvider);
  final companyAttendanceAsync = ref.watch(companyAttendanceStreamProvider);
  final todayStr = ref.watch(todayDateStringProvider);

  if (employeesAsync is AsyncLoading || companyAttendanceAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (employeesAsync is AsyncError) {
    return AsyncValue.error(employeesAsync.error!, employeesAsync.stackTrace!);
  }
  if (companyAttendanceAsync is AsyncError) {
    return AsyncValue.error(companyAttendanceAsync.error!, companyAttendanceAsync.stackTrace!);
  }

  final employees = employeesAsync.value ?? [];
  final attendanceList = companyAttendanceAsync.value ?? [];

  // Filter today's attendance records
  final todayRecords = attendanceList.where((rec) {
    final dateFormatted = '${rec.date.year}-${rec.date.month.toString().padLeft(2, '0')}-${rec.date.day.toString().padLeft(2, '0')}';
    return dateFormatted == todayStr;
  }).toList();

  final activeEmployees = employees.where((e) => e.status == 'Active').toList();
  final totalEmployeesCount = activeEmployees.length;

  int present = 0;
  int lateCount = 0;
  int onLeave = 0;

  for (final emp in activeEmployees) {
    final record = todayRecords.firstWhere(
      (rec) => rec.employeeId == emp.employeeId,
      orElse: () => AttendanceModel(
        attendanceId: '',
        companyId: '',
        employeeId: '',
        uid: '',
        date: DateTime.now(),
        workingHours: 0,
        status: 'Absent',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (record.attendanceId.isNotEmpty) {
      final status = record.status.toLowerCase();
      if (status == 'present' || status == 'late' || status == 'half day') {
        present++;
      }
      if (status == 'late') {
        lateCount++;
      }
      if (status == 'leave') {
        onLeave++;
      }
    }
  }

  final absent = totalEmployeesCount - present - onLeave;

  return AsyncValue.data(AttendanceStats(
    totalEmployees: totalEmployeesCount,
    present: present,
    absent: absent < 0 ? 0 : absent,
    lateCount: lateCount,
    onLeave: onLeave,
  ));
});

// Search & Filter State Providers
final attendanceSearchNameQueryProvider = StateProvider<String>((ref) => '');
final attendanceSearchDepartmentProvider = StateProvider<String>((ref) => 'All');
final attendanceSearchDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Joined Model containing both Attendance and Employee details
class JoinedAttendanceRecord {
  final AttendanceModel attendance;
  final EmployeeModel employee;

  JoinedAttendanceRecord({
    required this.attendance,
    required this.employee,
  });
}

// Provider for searched/filtered attendance records (for HR search module)
final searchedAttendanceProvider = Provider<AsyncValue<List<JoinedAttendanceRecord>>>((ref) {
  final employeesAsync = ref.watch(allActiveEmployeesProvider);
  final companyAttendanceAsync = ref.watch(companyAttendanceStreamProvider);
  
  final nameQuery = ref.watch(attendanceSearchNameQueryProvider).trim().toLowerCase();
  final departmentFilter = ref.watch(attendanceSearchDepartmentProvider);
  final targetDate = ref.watch(attendanceSearchDateProvider);

  if (employeesAsync is AsyncLoading || companyAttendanceAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (employeesAsync is AsyncError) {
    return AsyncValue.error(employeesAsync.error!, employeesAsync.stackTrace!);
  }
  if (companyAttendanceAsync is AsyncError) {
    return AsyncValue.error(companyAttendanceAsync.error!, companyAttendanceAsync.stackTrace!);
  }

  final employees = employeesAsync.value ?? [];
  final attendanceList = companyAttendanceAsync.value ?? [];

  // Filter and Join
  final targetDateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
  final joinedList = <JoinedAttendanceRecord>[];

  // For the searched date, show all active employees and their status
  for (final employee in employees) {
    // Check if there is an attendance record for this date
    final record = attendanceList.firstWhere(
      (rec) {
        final recDateStr = '${rec.date.year}-${rec.date.month.toString().padLeft(2, '0')}-${rec.date.day.toString().padLeft(2, '0')}';
        return rec.employeeId == employee.employeeId && recDateStr == targetDateStr;
      },
      orElse: () => AttendanceModel(
        attendanceId: 'absent_${employee.employeeId}_$targetDateStr',
        companyId: employee.companyId,
        employeeId: employee.employeeId,
        uid: employee.uid,
        date: targetDate,
        workingHours: 0,
        status: 'Absent',
        remarks: 'No record found',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Apply Search Query Filter (Name or ID)
    if (nameQuery.isNotEmpty) {
      final nameMatches = employee.name.toLowerCase().contains(nameQuery);
      final idMatches = employee.employeeId.toLowerCase().contains(nameQuery);
      if (!nameMatches && !idMatches) {
        continue;
      }
    }

    // Apply Department Filter
    if (departmentFilter != 'All' && employee.department != departmentFilter) {
      continue;
    }

    joinedList.add(JoinedAttendanceRecord(
      attendance: record,
      employee: employee,
    ));
  }

  return AsyncValue.data(joinedList);
});

// Filters for History Module
final historyStartDateProvider = StateProvider<DateTime?>((ref) => null);
final historyEndDateProvider = StateProvider<DateTime?>((ref) => null);
final historyEmployeeFilterProvider = StateProvider<String?>((ref) => null); // Null means All employees for HR, or current employee for Employee

// Provider for filtered history list
final filteredHistoryProvider = Provider<AsyncValue<List<JoinedAttendanceRecord>>>((ref) {
  final employeesAsync = ref.watch(allActiveEmployeesProvider);
  final companyAttendanceAsync = ref.watch(companyAttendanceStreamProvider);
  
  final startDate = ref.watch(historyStartDateProvider);
  final endDate = ref.watch(historyEndDateProvider);
  final selectedEmployeeId = ref.watch(historyEmployeeFilterProvider);

  if (employeesAsync is AsyncLoading || companyAttendanceAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (employeesAsync is AsyncError) {
    return AsyncValue.error(employeesAsync.error!, employeesAsync.stackTrace!);
  }
  if (companyAttendanceAsync is AsyncError) {
    return AsyncValue.error(companyAttendanceAsync.error!, companyAttendanceAsync.stackTrace!);
  }

  final employees = employeesAsync.value ?? [];
  final attendanceList = companyAttendanceAsync.value ?? [];

  final joinedList = <JoinedAttendanceRecord>[];

  for (final record in attendanceList) {
    // Find matching employee details
    final emp = employees.firstWhere(
      (e) => e.employeeId == record.employeeId,
      orElse: () => EmployeeModel(
        employeeId: record.employeeId,
        uid: record.uid,
        companyId: record.companyId,
        name: 'Unknown Employee',
        email: '',
        phone: '',
        role: 'Employee',
        department: 'N/A',
        designation: 'N/A',
        status: 'Inactive',
        joiningDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Apply Employee Filter
    if (selectedEmployeeId != null && selectedEmployeeId != 'All' && record.employeeId != selectedEmployeeId) {
      continue;
    }

    // Apply Date Range Filter
    if (startDate != null) {
      // Set time to midnight for clean comparison
      final recordZero = DateTime(record.date.year, record.date.month, record.date.day);
      final startZero = DateTime(startDate.year, startDate.month, startDate.day);
      if (recordZero.isBefore(startZero)) continue;
    }
    if (endDate != null) {
      final recordZero = DateTime(record.date.year, record.date.month, record.date.day);
      final endZero = DateTime(endDate.year, endDate.month, endDate.day);
      if (recordZero.isAfter(endZero)) continue;
    }

    joinedList.add(JoinedAttendanceRecord(
      attendance: record,
      employee: emp,
    ));
  }

  return AsyncValue.data(joinedList);
});

// Summary scorecard for a month
class MonthlySummary {
  final int totalWorkingDays;
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final int holidays;
  final double totalWorkingHours;
  final double attendancePercentage;

  MonthlySummary({
    required this.totalWorkingDays,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.holidays,
    required this.totalWorkingHours,
    required this.attendancePercentage,
  });
}

// Family provider to calculate monthly summary scorecard for an employee and selected month
final monthlySummaryProvider = Provider.family<AsyncValue<MonthlySummary>, ({String employeeId, DateTime month})>((ref, arg) {
  final historyAsync = ref.watch(employeeAttendanceHistoryProvider(arg.employeeId));

  if (historyAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (historyAsync is AsyncError) {
    return AsyncValue.error(historyAsync.error!, historyAsync.stackTrace!);
  }

  final records = historyAsync.value ?? [];

  // Filter records by the selected month & year
  final monthRecords = records.where((r) => r.date.month == arg.month.month && r.date.year == arg.month.year).toList();

  // Calculate standard weekdays (Mon-Fri) in the selected month up to today (if today is in the selected month) or for the whole month.
  final now = DateTime.now();
  final int year = arg.month.year;
  final int month = arg.month.month;
  
  // Find total days in that month
  final daysInMonth = DateTime(year, month + 1, 0).day;
  
  // Calculate expected working days (excluding weekends: Sat/Sun)
  int expectedWorkingDays = 0;
  final endDay = (now.year == year && now.month == month) ? now.day : daysInMonth;
  for (int d = 1; d <= endDay; d++) {
    final dayOfWeek = DateTime(year, month, d).weekday;
    if (dayOfWeek != DateTime.saturday && dayOfWeek != DateTime.sunday) {
      expectedWorkingDays++;
    }
  }

  int present = 0;
  int absent = 0;
  int halfDay = 0;
  int leave = 0;
  int holiday = 0;
  double workingHours = 0.0;

  for (final rec in monthRecords) {
    final status = rec.status.toLowerCase();
    workingHours += rec.workingHours;

    if (status == 'present') {
      present++;
    } else if (status == 'late') {
      present++; // late counts as present for days count
    } else if (status == 'absent') {
      absent++;
    } else if (status == 'half day') {
      halfDay++;
    } else if (status == 'leave') {
      leave++;
    } else if (status == 'holiday') {
      holiday++;
    }
  }

  // Attendance percentage: (Present + HalfDay * 0.5) / Expected Days * 100
  // Fallback to 100% if expected working days is 0.
  final divisor = expectedWorkingDays > 0 ? expectedWorkingDays : 1;
  final double percentage = ((present + (halfDay * 0.5)) / divisor) * 100;

  return AsyncValue.data(MonthlySummary(
    totalWorkingDays: expectedWorkingDays,
    presentDays: present,
    absentDays: absent,
    halfDays: halfDay,
    leaveDays: leave,
    holidays: holiday,
    totalWorkingHours: workingHours,
    attendancePercentage: percentage > 100 ? 100.0 : (percentage < 0 ? 0.0 : percentage),
  ));
});
