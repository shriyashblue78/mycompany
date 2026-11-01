import '../models/rejection_reason_model.dart';

abstract class RejectionReasonRepository {
  Future<void> createReason(String companyId, RejectionReasonModel reason);
  Future<void> updateReason(String companyId, RejectionReasonModel reason);
  Future<void> deleteReason(String companyId, String reasonId);
  Stream<List<RejectionReasonModel>> streamReasons(String companyId);
  Future<bool> isReasonNameTaken(String companyId, String reasonName, {String? excludeReasonId});
}
