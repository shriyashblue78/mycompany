import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/models/company_model.dart';
import '../providers/super_admin_provider.dart';

class SuperAdminCompanyListScreen extends ConsumerWidget {
  const SuperAdminCompanyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final companiesAsync = ref.watch(filteredCompaniesProvider);
    final searchQuery = ref.watch(companySearchQueryProvider);
    final statusFilter = ref.watch(companyStatusFilterProvider);
    final industryFilter = ref.watch(companyIndustryFilterProvider);
    final selectedSort = ref.watch(companySortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Companies'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: Column(
        children: [
          // Filter section
          _buildFilterHeader(context, ref, searchQuery, statusFilter, industryFilter, selectedSort, theme),

          // Stream list
          Expanded(
            child: companiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading companies: $err')),
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState(context, theme);
                }
                return _buildListView(context, list, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(
    BuildContext context,
    WidgetRef ref,
    String query,
    String? status,
    String? industry,
    String sort,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withAlpha(26),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (val) => ref.read(companySearchQueryProvider.notifier).state = val,
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: query,
                selection: TextSelection.collapsed(offset: query.length),
              ),
            ),
            decoration: InputDecoration(
              hintText: 'Search by Company Name, Code, or Industry...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => ref.read(companySearchQueryProvider.notifier).state = '',
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSizes.p16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p12),

          // Filters Row
          Row(
            children: [
              // Status Dropdown
              Expanded(
                child: _buildDropdownFilter(
                  hint: 'Status',
                  value: status,
                  items: const ['All', 'Active', 'Suspended', 'Trial', 'Expired'],
                  onChanged: (val) {
                    ref.read(companyStatusFilterProvider.notifier).state = val == 'All' ? null : val;
                  },
                ),
              ),
              const SizedBox(width: AppSizes.p8),

              // Industry Dropdown
              Expanded(
                child: _buildDropdownFilter(
                  hint: 'Industry',
                  value: industry,
                  items: const ['All', 'Manufacturing', 'Logistics', 'Retail', 'Service', 'Technology'],
                  onChanged: (val) {
                    ref.read(companyIndustryFilterProvider.notifier).state = val == 'All' ? null : val;
                  },
                ),
              ),
              const SizedBox(width: AppSizes.p8),

              // Sort Dropdown
              Expanded(
                child: _buildDropdownFilter(
                  hint: 'Sort By',
                  value: sort,
                  items: const ['Name A-Z', 'Name Z-A', 'Created Date'],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(companySortProvider.notifier).state = val;
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? 'All',
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.domain_disabled_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No companies found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              'Please adjust your filter status or search term.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<CompanyModel> list, bool isDark) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.p16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final company = list[index];

        return Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            onTap: () {
              context.push('/super-admin/company/${company.companyId}');
            },
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withAlpha(26),
              radius: 24,
              child: Text(
                company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    company.companyName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(company.status, _getStatusColor(company.status)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Code: ${company.companyCode}',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        company.industry,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plan: ${company.subscriptionPlan}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Joined: ${DateFormat('MMM d, yyyy').format(company.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.success;
      case 'Suspended':
        return AppColors.error;
      case 'Trial':
        return AppColors.warning;
      case 'Expired':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}
