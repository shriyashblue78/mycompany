import '../models/sale_model.dart';

abstract class SaleRepository {
  Future<void> createSale(String companyId, SaleModel sale);
  Future<void> updateSale(String companyId, SaleModel sale);
  Future<void> deleteSale(String companyId, String saleId);
  Stream<List<SaleModel>> streamSales(String companyId);
  Stream<SaleModel?> streamSaleById(String companyId, String saleId);
}
