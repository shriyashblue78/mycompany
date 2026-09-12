import '../models/inward_outward_model.dart';

abstract class InwardOutwardRepository {
  Future<void> addRecord(String companyId, InwardOutwardModel record);
  Future<void> updateRecord(String companyId, InwardOutwardModel record);
  Future<void> deleteRecord(String companyId, String recordId);
  Stream<List<InwardOutwardModel>> streamRecords(String companyId);
}
