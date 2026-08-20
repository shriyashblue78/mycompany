import '../models/production_model.dart';

abstract class ProductionRepository {
  Future<void> createProduction(String companyId, ProductionModel production);
  Future<void> updateProduction(String companyId, ProductionModel production);
  Future<void> deleteProduction(String companyId, String productionId);
  Stream<List<ProductionModel>> streamProductions(String companyId);
  Stream<ProductionModel?> streamProductionById(String companyId, String productionId);
}
