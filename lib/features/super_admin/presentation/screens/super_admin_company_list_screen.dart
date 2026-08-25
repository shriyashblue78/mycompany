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
    final allCompaniesAsync = ref.watch(companiesStreamProvider);
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

          // Pending Requests banner
          allCompaniesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (allList) {
              final pending = allList.where((c) => c.requestStatus == 'pending').toList();
              if (pending.isEmpty) return const SizedBox.shrink();
              return _buildPendingRequestsSection(context, ref, pending, theme, isDark);
            },
          ),

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

  Widget _buildPendingRequestsSection(
    BuildContext context,
    WidgetRef ref,
    List<CompanyModel> pending,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: Colors.amber.withOpacity(0.2),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending Seat Increase Requests (${pending.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final company = pending[idx];
                return _buildPendingRequestCard(context, ref, company, theme, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(
    BuildContext context,
    WidgetRef ref,
    CompanyModel company,
    ThemeData theme,
    bool isDark,
  ) {
    final requested = company.requestedSeats ?? 0;
    final current = company.maxEmployees;
    final target = company.requestNewLimit ?? (current + requested);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            company.companyName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Current limit: $current → Requested limit: $target (+$requested)',
            style: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.8), fontSize: 11),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _handleRequestAction(context, ref, company, approve: false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _handleRequestAction(context, ref, company, approve: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                ),
                child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleRequestAction(
    BuildContext context,
    WidgetRef ref,
    CompanyModel company, {
    required bool approve,
  }) {
    final actionText = approve ? 'Approve' : 'Reject';
    final targetLimit = company.requestNewLimit ?? company.maxEmployees;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('$actionText Seat Request?'),
          content: Text(approve
              ? 'Are you sure you want to approve the request for +${company.requestedSeats} seats? This will increase the company seat limit from ${company.maxEmployees} to $targetLimit immediately.'
              : 'Are you sure you want to reject the request for +${company.requestedSeats} seats? The owner will be notified of the rejection.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final repo = ref.read(superAdminRepositoryProvider);

                try {
                  CompanyModel updated;
                  if (approve) {
                    updated = company.copyWith(
                      maxEmployees: targetLimit,
                      requestStatus: 'approved',
                      updatedAt: DateTime.now(),
                    );
                  } else {
                    updated = company.copyWith(
                      requestStatus: 'rejected',
                      updatedAt: DateTime.now(),
                    );
                  }

                  await repo.updateCompany(updated);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Seat increase request ${approve ? "approved" : "rejected"} successfully.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating request: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? AppColors.success : AppColors.error,
              ),
              child: Text(actionText, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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
          child: InkWell(
            onTap: () {
              context.push('/super-admin/company/${company.companyId}');
            },
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Logo, Name, App Access Status, Chevron
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withAlpha(26),
                        radius: 22,
                        child: Text(
                          company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.p12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company.companyName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: ${company.companyCode}  •  ${company.industry}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // App Access Badge
                      _buildAppAccessBadge(company.status),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurface.withAlpha(77)),
                    ],
                  ),
                  const SizedBox(height: AppSizes.p12),
                  const Divider(height: 1),
                  const SizedBox(height: AppSizes.p12),
                  // Details Row: Seats, Subscription Plan, Joined
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Seats Usage
                      Consumer(
                        builder: (context, ref, child) {
                          final countAsync = ref.watch(companyEmployeeCountProvider(company.companyId));
                          return countAsync.when(
                            loading: () => Text('Seats: -- / ${company.maxEmployees}', style: theme.textTheme.bodySmall),
                            error: (_, __) => Text('Seats: Error / ${company.maxEmployees}', style: theme.textTheme.bodySmall),
                            data: (count) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt_rounded, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Seats: $count / ${company.maxEmployees}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
                  const SizedBox(height: AppSizes.p12),
                  // Enabled Modules Row
                  if (company.enabledModules.isNotEmpty) ...[
                    Text(
                      'Enabled Modules:',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: company.enabledModules.map((mod) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
                          ),
                          child: Text(
                            mod.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppAccessBadge(String status) {
    final isON = status == 'Active' || status == 'Trial';
    final label = isON ? 'APP ACCESS: ON' : 'APP ACCESS: OFF';
    final color = isON ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80), width: 1),
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
