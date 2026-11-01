import '../models/clearance_type_model.dart';

abstract class ClearanceTypeRepository {
  Future<void> createClearanceType(String companyId, ClearanceTypeModel clearance);
  Future<void> updateClearanceType(String companyId, ClearanceTypeModel clearance);
  Future<void> deleteClearanceType(String companyId, String clearanceId);
  Stream<List<ClearanceTypeModel>> streamClearanceTypes(String companyId);
  Future<bool> isDuplicate(String companyId, String clearanceType, {String? excludeId});
}
