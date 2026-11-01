import '../../domain/models/hsn_sac_model.dart';

abstract class HsnSacRepository {
  Future<void> createHsnSac(String companyId, HsnSacModel item);
  Future<void> updateHsnSac(String companyId, HsnSacModel item);
  Future<void> deleteHsnSac(String companyId, String hsnSacId);
  Stream<List<HsnSacModel>> streamHsnSac(String companyId);
  Future<bool> isCodeTaken(String companyId, String code, {String? excludeId});
  Future<bool> isHsnSacReferenced(String companyId, String code);
}
