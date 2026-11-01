import '../models/pdi_master_model.dart';

abstract class PdiMasterRepository {
  Future<void> createPdi(String companyId, PdiMasterModel pdi);
  Future<void> updatePdi(String companyId, PdiMasterModel pdi);
  Future<void> deletePdi(String companyId, String pdiId);
  Stream<List<PdiMasterModel>> streamPdiList(String companyId);
  Future<bool> isDuplicate(String companyId, String itemName, String partNo, {String? excludePdiId});
}
