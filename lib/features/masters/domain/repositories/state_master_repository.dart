import '../models/state_master_model.dart';

abstract class StateMasterRepository {
  Future<void> createState(String companyId, StateMasterModel state);
  Future<void> updateState(String companyId, StateMasterModel state);
  Future<void> deleteState(String companyId, String stateId);
  Stream<List<StateMasterModel>> streamStates(String companyId);
  Future<bool> isDuplicate(String companyId, String stateName, String stateCode, {String? excludeStateId});
  Future<void> seedDefaultIndianStatesIfEmpty(String companyId);
}
