import '../../../auth/domain/models/company_model.dart';

abstract class SuperAdminRepository {
  /// Stream of all companies
  Stream<List<CompanyModel>> streamCompanies();

  /// Stream of a single company's details
  Stream<CompanyModel?> streamCompanyById(String companyId);

  /// Create a new company (Workspace registration)
  Future<void> createCompany(CompanyModel company);

  /// Update company profile details
  Future<void> updateCompany(CompanyModel company);

  /// Suspend a company
  Future<void> suspendCompany(String companyId);

  /// Activate a company
  Future<void> activateCompany(String companyId);

  /// Archive a company instead of permanently deleting
  Future<void> archiveCompany(String companyId);

  /// Auto-generate next company code in sequence transactionally (CMP0001, CMP0002, etc.)
  Future<String> generateNextCompanyCode();

  /// Check if a company name already exists (Duplicate Name validation)
  Future<bool> isCompanyNameDuplicate(String name);

  /// Check if a company code already exists (Duplicate Code validation)
  Future<bool> isCompanyCodeDuplicate(String code);
}
