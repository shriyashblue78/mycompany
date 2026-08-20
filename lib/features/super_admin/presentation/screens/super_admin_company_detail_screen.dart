import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/models/company_model.dart';
import '../providers/super_admin_provider.dart';
import '../../../../core/widgets/responsive_layout.dart';

class SuperAdminCompanyDetailScreen extends ConsumerWidget {
  final String companyId;

  const SuperAdminCompanyDetailScreen({
    super.key,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final companyAsync = ref.watch(companyDetailsStreamProvider(companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Account Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
            tooltip: 'Edit Company Profile',
            onPressed: () => context.push('/super-admin/company/$companyId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Company Operational Settings',
            onPressed: () => context.push('/super-admin/company/$companyId/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (company) {
          if (company == null) {
            return const Center(child: Text('Company record not found.'));
          }

          final statusColor = _getStatusColor(company.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Row
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withAlpha(26),
                          radius: 36,
                          child: Text(
                            company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company.companyName,
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildBadge(company.status, statusColor),
                                  const SizedBox(width: 8),
                                  _buildBadge(company.subscriptionPlan, theme.colorScheme.primary, outlined: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSizes.p40),

                    // Two Column Grid for Metadata
                    GridView.count(
                      crossAxisCount: ResponsiveLayout.isMobile(context) ? 1 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSizes.p20,
                      mainAxisSpacing: AppSizes.p20,
                      childAspectRatio: 2.2,
                      children: [
                        _buildInfoCard(
                          theme,
                          isDark,
                          title: 'Company Information',
                          icon: Icons.info_outline,
                          fields: {
                            'Company Code': company.companyCode,
                            'Industry Sector': company.industry,
                            'Registered Date': DateFormat('MMMM d, yyyy').format(company.createdAt),
                          },
                        ),
                        _buildInfoCard(
                          theme,
                          isDark,
                          title: 'Contact Details',
                          icon: Icons.contact_mail_outlined,
                          fields: {
                            'Email Address': company.email,
                            'Phone Number': company.phone,
                            'Last Database Sync': DateFormat('MMM d, yyyy h:mm a').format(company.updatedAt),
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Primary Owner Card
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        side: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Company Primary Owner',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => context.push('/super-admin/company/${company.companyId}/owner'),
                                  icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                                  label: const Text('Manage Account', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withAlpha(26),
                                  child: Text(
                                    company.ownerName.isNotEmpty ? company.ownerName[0].toUpperCase() : 'O',
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company.ownerName.isNotEmpty ? company.ownerName : 'No Owner Provisioned',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Email: ${company.ownerEmail.isNotEmpty ? company.ownerEmail : "N/A"}  •  Phone: ${company.ownerPhone.isNotEmpty ? company.ownerPhone : "N/A"}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                _buildBadge(company.ownerStatus, _getStatusColor(company.ownerStatus)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Subscription Plan Details Card
                    _buildSubscriptionCard(theme, isDark, company),
                    const SizedBox(height: AppSizes.p24),

                    // Operational Metrics Placeholders
                    Text(
                      'Operational Instance Telemetry',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildMetricsGrid(context),
                    const SizedBox(height: AppSizes.p32),

                    // Action Controls Block
                    Text(
                      'Administrative Management Actions',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildActionControls(context, ref, company, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    bool isDark, {
    required String title,
    required IconData icon,
    required Map<String, String> fields,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...fields.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withAlpha(153)),
                    ),
                    Text(
                      entry.value,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(ThemeData theme, bool isDark, CompanyModel company) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isDark ? theme.colorScheme.surface : Colors.blue.shade50.withAlpha(51),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.colorScheme.primary.withAlpha(51), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withAlpha(26),
              radius: 28,
              child: Icon(Icons.star_rounded, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${company.subscriptionPlan} Plan',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unlimited active employees configuration, database isolation container active, regular automatic backups active.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.p16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Pricing model',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  _getPlanPrice(company.subscriptionPlan),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = [
      _MetricItem('Employees', 'Placeholder', Icons.people, Colors.blue),
      _MetricItem('Attendance Today', 'Placeholder', Icons.fingerprint, Colors.teal),
      _MetricItem('Active Tasks', 'Placeholder', Icons.checklist_rounded, Colors.amber),
      _MetricItem('Active Leaves', 'Placeholder', Icons.time_to_leave_rounded, Colors.purple),
      _MetricItem('Inventory SKU', 'Placeholder', Icons.inventory_2_rounded, Colors.deepOrange),
    ];

    final columns = ResponsiveLayout.isMobile(context) ? 1 : metrics.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p12,
        mainAxisSpacing: AppSizes.p12,
        childAspectRatio: columns == 1 ? 4.5 : 1.5,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(m.icon, color: m.color, size: 24),
                const SizedBox(height: 8),
                Text(
                  m.title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  m.value,
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionControls(
    BuildContext context,
    WidgetRef ref,
    CompanyModel company,
    ThemeData theme,
  ) {
    final canSuspend = company.status == 'Active' || company.status == 'Trial';
    final canActivate = company.status == 'Suspended' || company.status == 'Expired';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceEvenly,
        children: [
          // Activate Button
          ElevatedButton.icon(
            onPressed: canActivate
                ? () => _confirmAction(context, ref, 'Activate', () {
                      ref.read(superAdminRepositoryProvider).activateCompany(company.companyId);
                    })
                : null,
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text('Activate Workspace', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              ),
            ),
          ),

          // Suspend Button
          ElevatedButton.icon(
            onPressed: canSuspend
                ? () => _confirmAction(context, ref, 'Suspend', () {
                      ref.read(superAdminRepositoryProvider).suspendCompany(company.companyId);
                    })
                : null,
            icon: const Icon(Icons.pause_rounded, color: Colors.white),
            label: const Text('Suspend Workspace', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              ),
            ),
          ),

          // Archive Button (instead of deleteCompany)
          ElevatedButton.icon(
            onPressed: company.status != 'Archived'
                ? () => _confirmAction(context, ref, 'Archive', () {
                      ref.read(superAdminRepositoryProvider).archiveCompany(company.companyId);
                      context.pop(); // Go back after archiving
                    })
                : null,
            icon: const Icon(Icons.archive_rounded, color: Colors.white),
            label: const Text('Archive Tenant', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    VoidCallback onConfirmed,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$action Company Instance?'),
          content: Text('Are you sure you want to perform this administrative operation? This changes instance status immediately.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onConfirmed();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'Archive'
                    ? AppColors.error
                    : action == 'Suspend'
                        ? AppColors.warning
                        : AppColors.success,
              ),
              child: Text(action, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _getPlanPrice(String plan) {
    switch (plan) {
      case 'Starter':
        return '\$49/mo';
      case 'Professional':
        return '\$99/mo';
      case 'Enterprise':
        return '\$249/mo';
      default:
        return 'Free Trial';
    }
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

  Widget _buildBadge(String label, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withAlpha(38),
        border: outlined ? Border.all(color: color, width: 1.5) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem(this.title, this.value, this.icon, this.color);
}
