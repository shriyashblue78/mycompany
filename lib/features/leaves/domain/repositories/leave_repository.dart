import '../models/leave_model.dart';

abstract class LeaveRepository {
  Future<void> createLeave(String companyId, LeaveModel leave);
  Future<void> updateLeave(String companyId, LeaveModel leave);
  Stream<List<LeaveModel>> streamLeaves(String companyId);
  Stream<LeaveModel?> streamLeaveById(String companyId, String leaveId);
}
