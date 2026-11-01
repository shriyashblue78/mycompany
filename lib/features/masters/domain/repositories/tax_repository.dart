import '../../domain/models/tax_model.dart';

abstract class TaxRepository {
  Future<void> createTax(String companyId, TaxModel tax);
  Future<void> updateTax(String companyId, TaxModel tax);
  Future<void> deleteTax(String companyId, String taxId);
  Stream<List<TaxModel>> streamTaxes(String companyId);
  Stream<TaxModel?> streamTaxById(String companyId, String taxId);
  Future<bool> isTaxCategoryTaken(String companyId, String taxCategory, {String? excludeTaxId});
  Future<bool> isTaxReferenced(String companyId, String taxId, String taxCategory);
}
