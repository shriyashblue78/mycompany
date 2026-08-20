import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../providers/super_admin_provider.dart';
import '../widgets/super_admin_drawer.dart';

class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(superAdminDashboardStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const SuperAdminDrawer(),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (stats) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      _buildHeaderCard(context, theme),
                      const SizedBox(height: AppSizes.p24),

                      // Stats Grid
                      Text(
                        'Global Metrics',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildStatsGrid(context, stats),
                      const SizedBox(height: AppSizes.p24),

                      // Quick Actions
                      Text(
                        'Operations Console',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildActionsGrid(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.white, size: 32),
              const SizedBox(width: AppSizes.p12),
              Text(
                'ERP ROOT MANAGEMENT SYSTEM',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p16),
          Text(
            'Platform Control Panel',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.p8),
          Text(
            'Monitor multi-tenant instances, manage company subscriptions, activate, suspend, or archive tenants globally.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withAlpha(217),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, SuperAdminDashboardStats stats) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 2
        : ResponsiveLayout.isTablet(context)
            ? 3
            : 5;

    final cards = [
      _SAStatItem('Total Companies', stats.total.toString(), Icons.business_rounded, AppColors.info),
      _SAStatItem('Active', stats.active.toString(), Icons.check_circle_rounded, AppColors.success),
      _SAStatItem('Suspended', stats.suspended.toString(), Icons.block_rounded, AppColors.error),
      _SAStatItem('Trial Instances', stats.trial.toString(), Icons.hourglass_top_rounded, AppColors.warning),
      _SAStatItem('Expiring Soon', stats.expiringSoon.toString(), Icons.notification_important_rounded, Colors.purple),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: 96,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return CustomCard(
          title: card.title,
          subtitle: card.value,
          icon: card.icon,
          iconColor: card.color,
        );
      },
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    final List<Widget> actions = [
      _buildActionCard(
        context,
        'Companies Directory',
        'Manage tenant registration, details, status.',
        Icons.list_alt_rounded,
        AppColors.info,
        () => context.push('/super-admin/companies'),
        true,
      ),
      _buildActionCard(
        context,
        'Create Tenant Company',
        'Register new company configuration workspace.',
        Icons.add_business_rounded,
        AppColors.warning,
        () => context.push('/super-admin/create-company'),
        true, // Enabled router placeholder screen as requested
      ),
      _buildActionCard(
        context,
        'Platform Analytics',
        'Analyze system resource consumption and statistics.',
        Icons.bar_chart_rounded,
        AppColors.success,
        () => _showPlaceholderDialog(context, 'Platform Analytics'),
        false,
      ),
    ];

    final columns = ResponsiveLayout.isMobile(context)
        ? 2
        : ResponsiveLayout.isTablet(context)
            ? 2
            : actions.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: 96,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => actions[index],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool enabled,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: enabled ? color.withAlpha(26) : Colors.grey.withAlpha(26),
                child: Icon(icon, color: enabled ? color : Colors.grey),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: enabled ? null : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withAlpha(153),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withAlpha(77)),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaceholderDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return ResponsiveDialog(
          child: AlertDialog(
            title: Text('$title - Preview Mode'),
            content: Text('The $title metrics panel is currently under construction and will be active in the next release.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SAStatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SAStatItem(this.title, this.value, this.icon, this.color);
}
