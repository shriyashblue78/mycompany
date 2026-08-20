import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/models/company_model.dart';
import '../../domain/repositories/super_admin_repository.dart';
import '../../data/repositories/super_admin_repository_impl.dart';

// Repository Provider
final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepositoryImpl();
});

// Search and Filter State Providers
final companySearchQueryProvider = StateProvider<String>((ref) => '');
final companyStatusFilterProvider = StateProvider<String?>((ref) => null);
final companySortProvider = StateProvider<String>((ref) => 'Name A-Z');
final companyIndustryFilterProvider = StateProvider<String?>((ref) => null);

// Stream Provider for all companies
final companiesStreamProvider = StreamProvider<List<CompanyModel>>((ref) {
  return ref.watch(superAdminRepositoryProvider).streamCompanies();
});

// Stream Provider for a single company's details
final companyDetailsStreamProvider = StreamProvider.family<CompanyModel?, String>((ref, companyId) {
  return ref.watch(superAdminRepositoryProvider).streamCompanyById(companyId);
});

// Filtered and sorted companies stream
final filteredCompaniesProvider = StreamProvider<List<CompanyModel>>((ref) {
  final companiesAsync = ref.watch(companiesStreamProvider);

  return companiesAsync.when(
    loading: () => Stream.value(<CompanyModel>[]),
    error: (err, stack) => Stream.value(<CompanyModel>[]),
    data: (companies) {
      final query = ref.watch(companySearchQueryProvider).trim().toLowerCase();
      final statusFilter = ref.watch(companyStatusFilterProvider);
      final industryFilter = ref.watch(companyIndustryFilterProvider);
      final sortOrder = ref.watch(companySortProvider);

      // Filter
      var list = companies.where((c) => c.status != 'Archived').toList(); // Hide archived from main list by default

      if (statusFilter != null && statusFilter != 'All') {
        list = list.where((c) => c.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }

      if (industryFilter != null && industryFilter != 'All') {
        list = list.where((c) => c.industry.toLowerCase() == industryFilter.toLowerCase()).toList();
      }

      if (query.isNotEmpty) {
        list = list.where((c) {
          final nameMatch = c.companyName.toLowerCase().contains(query);
          final codeMatch = c.companyCode.toLowerCase().contains(query);
          final industryMatch = c.industry.toLowerCase().contains(query);
          return nameMatch || codeMatch || industryMatch;
        }).toList();
      }

      // Sort
      if (sortOrder == 'Name A-Z') {
        list.sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
      } else if (sortOrder == 'Name Z-A') {
        list.sort((a, b) => b.companyName.toLowerCase().compareTo(a.companyName.toLowerCase()));
      } else if (sortOrder == 'Created Date') {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return Stream.value(list);
    },
  );
});

// Dashboard stats structure
class SuperAdminDashboardStats {
  final int total;
  final int active;
  final int suspended;
  final int trial;
  final int expiringSoon;

  const SuperAdminDashboardStats({
    required this.total,
    required this.active,
    required this.suspended,
    required this.trial,
    required this.expiringSoon,
  });
}

// Dashboard stats stream
final superAdminDashboardStatsProvider = StreamProvider<SuperAdminDashboardStats>((ref) {
  final companiesAsync = ref.watch(companiesStreamProvider);

  return companiesAsync.when(
    loading: () => Stream.value(const SuperAdminDashboardStats(total: 0, active: 0, suspended: 0, trial: 0, expiringSoon: 0)),
    error: (err, stack) => Stream.value(const SuperAdminDashboardStats(total: 0, active: 0, suspended: 0, trial: 0, expiringSoon: 0)),
    data: (companies) {
      final nonArchived = companies.where((c) => c.status != 'Archived').toList();

      final total = nonArchived.length;
      final active = nonArchived.where((c) => c.status == 'Active').length;
      final suspended = nonArchived.where((c) => c.status == 'Suspended').length;
      final trial = nonArchived.where((c) => c.status == 'Trial').length;

      return Stream.value(SuperAdminDashboardStats(
        total: total,
        active: active,
        suspended: suspended,
        trial: trial,
        expiringSoon: 0, // Placeholder
      ));
    },
  );
});
