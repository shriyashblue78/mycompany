import '../../domain/models/unit_model.dart';

abstract class UnitRepository {
  Future<void> createUnit(String companyId, UnitModel unit);
  Future<void> updateUnit(String companyId, UnitModel unit);
  Future<void> deleteUnit(String companyId, String unitId);
  Stream<List<UnitModel>> streamUnits(String companyId);
  Future<bool> isUnitReferenced(String companyId, String unitName);
}
