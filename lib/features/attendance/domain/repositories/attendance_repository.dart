import '../../domain/models/attendance_model.dart';

abstract class AttendanceRepository {
  /// Check-in to work. Creates a daily attendance record.
  /// Transactions are used internally to prevent duplicates.
  Future<void> checkIn(String companyId, AttendanceModel attendance);

  /// Check-out of work. Updates check-out time and calculates working hours.
  /// Transactions are used internally to guarantee consistency.
  Future<void> checkOut({
    required String companyId,
    required String attendanceId,
    required DateTime checkOutTime,
    required double workingHours,
    required String status,
    String? remarks,
  });

  /// Retrieve static today's attendance for an employee
  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
    String dateStr,
  );

  /// Real-time stream of today's attendance for an employee
  Stream<AttendanceModel?> streamTodayAttendance(
    String companyId,
    String employeeId,
    String dateStr,
  );

  /// Real-time stream of employee's attendance history
  Stream<List<AttendanceModel>> streamEmployeeAttendance(
    String companyId,
    String employeeId,
  );

  /// Real-time stream of all company-wide attendance records
  Stream<List<AttendanceModel>> streamCompanyAttendance(String companyId);

  /// Fetch all attendance records statically for exports or offline processing
  Future<List<AttendanceModel>> getCompanyAttendanceList(String companyId);
}
