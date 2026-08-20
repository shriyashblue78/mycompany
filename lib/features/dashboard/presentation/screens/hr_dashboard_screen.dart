import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../providers/dashboard_provider.dart';

class HRDashboardScreen extends ConsumerWidget {
  const HRDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final dashboardAsync = ref.watch(smartDashboardProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final userName = authState.userName ?? 'HR Manager';
    final company = authState.selectedCompany ?? 'Apex Industries';

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            company,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: const [
            NotificationBell(),
          ],
        ),
        drawer: const ERPDrawer(),
        body: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (stats) => _buildMobileBody(context, stats, userName, company, isDark, theme, authState.companyLogoUrl),
        ),
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('$company - HR Portal'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: const [
          NotificationBell(),
        ],
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Text('Error loading dashboard: $err',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ),
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
                        _buildCompanyLogoHeader(context, authState.companyLogoUrl, company, theme),
                        const SizedBox(height: AppSizes.p16),
                        _buildWelcomeCard(theme, userName, company, isDark),
                        const SizedBox(height: AppSizes.p24),
                        Text('Operations Analytics',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSizes.p12),
                        _buildStatsGrid(context, stats),
                        const SizedBox(height: AppSizes.p32),
                        Text('Quick Actions',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSizes.p12),
                        _buildQuickActions(context),
                        const SizedBox(height: AppSizes.p32),
                        Text('Recent Activity',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSizes.p12),
                        _buildRecentActivity(context, theme, stats.recentActivities),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompanyLogoHeader(BuildContext context, String? logoUrl, String companyName, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildLogoPlaceholder(companyName, theme),
              ),
            )
          else
            _buildLogoPlaceholder(companyName, theme),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here's what's happening in your company today.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder(String companyName, ThemeData theme) {
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context, DashboardStatsData stats,
      String userName, String company, bool isDark, ThemeData theme, String? logoUrl) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildCompanyLogoHeader(context, logoUrl, company, theme),
        const SizedBox(height: 16),
        MobileHeroCard(
          label: 'HR Portal',
          title: 'Welcome, $userName!',
          subtitle: 'Manage workforce for $company.',
          backgroundColor: isDark ? theme.colorScheme.surface : AppColors.primaryLight,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 20),
        Text('Workforce Overview', style: MobileText.sectionStyle(context)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 110,
          children: [
            MobileStatCard(
              label: 'Employees',
              value: '${stats.totalEmployees}',
              icon: Icons.people_rounded,
              color: Colors.blue,
              width: double.infinity,
              onTap: () => context.push('/employees'),
            ),
            MobileStatCard(
              label: 'Present Today',
              value: '${stats.presentToday}',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              width: double.infinity,
              onTap: () => context.push('/attendance'),
            ),
            MobileStatCard(
              label: 'Pending Leaves',
              value: '${stats.pendingLeaveRequests}',
              icon: Icons.time_to_leave_rounded,
              color: Colors.orange,
              width: double.infinity,
              onTap: () => context.push('/leaves'),
            ),
            MobileStatCard(
              label: 'Pending Tasks',
              value: '${stats.pendingTasks}',
              icon: Icons.task_rounded,
              color: Colors.indigo,
              width: double.infinity,
              onTap: () => context.push('/tasks'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Quick Actions', style: MobileText.sectionStyle(context)),
        const SizedBox(height: 10),
        _buildMobileQuickActions(context),
        const SizedBox(height: 24),
        Text('Recent Activity', style: MobileText.sectionStyle(context)),
        const SizedBox(height: 10),
        _buildMobileRecentActivity(context, theme, stats.recentActivities),
      ],
    );
  }

  Widget _buildMobileQuickActions(BuildContext context) {
    final actions = [
      _ActionData('Employees', Icons.people_rounded, Colors.blue, () => context.push('/employees')),
      _ActionData('Attendance', Icons.fingerprint_rounded, Colors.green, () => context.push('/attendance')),
      _ActionData('Leaves', Icons.time_to_leave_outlined, Colors.orange, () => context.push('/leaves')),
      _ActionData('Reports', Icons.bar_chart_rounded, Colors.purple, () => context.push('/reports')),
      _ActionData('Machines', Icons.settings_rounded, Colors.cyan, () => context.push('/machines')),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 68,
      children: actions.map((a) {
        return InkWell(
          onTap: a.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: a.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: a.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(a.icon, color: a.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: a.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileRecentActivity(
      BuildContext context, ThemeData theme, List<ActivityItem> activities) {
    if (activities.isEmpty) {
      return MobileCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No recent activity.',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ),
        ),
      );
    }
    return MobileCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
            itemBuilder: (_, i) {
              final act = activities[i];
              final t =
                  '${act.dateTime.hour.toString().padLeft(2, '0')}:${act.dateTime.minute.toString().padLeft(2, '0')}';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: act.color.withOpacity(0.15),
                  child: Icon(act.icon, color: act.color, size: 16),
                ),
                title: Text(act.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                trailing: Text(t,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              );
            },
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton(
              onPressed: () => context.push('/activity'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All Activity',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildWelcomeCard(ThemeData theme, String userName, String company, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p28, vertical: AppSizes.p24),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'HUMAN RESOURCES MANAGEMENT',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  'Welcome, $userName!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  'Track attendance, manage workforce shifts, process leave requests, and audit running company outputs for $company.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p16),
          Icon(
            Icons.badge_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, DashboardStatsData stats) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 2
        : ResponsiveLayout.isTablet(context)
            ? 3
            : 4;

    final cards = [
      _StatCardData('Total Employees', '${stats.totalEmployees}', Icons.people_rounded, Colors.blue),
      _StatCardData('Present Today', '${stats.presentToday}', Icons.check_circle_rounded, Colors.green),
      _StatCardData('Low Stock Items', '${stats.lowStockItems}', Icons.warning_amber_rounded, Colors.red),
      _StatCardData('Running Production', '${stats.runningProduction}', Icons.precision_manufacturing_rounded, Colors.purple),
      _StatCardData('Today\'s Purchases', '\$${stats.todayPurchasesAmount.toStringAsFixed(2)}', Icons.shopping_cart_rounded, Colors.teal),
      _StatCardData('Today\'s Sales', '₹${stats.todaySalesAmount.toStringAsFixed(0)}', Icons.monetization_on_rounded, Colors.amber),
      _StatCardData('Pending Leaves', '${stats.pendingLeaveRequests}', Icons.time_to_leave_rounded, Colors.orange),
      _StatCardData('Pending Tasks', '${stats.pendingTasks}', Icons.task_rounded, Colors.indigo),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p12,
        mainAxisSpacing: AppSizes.p12,
        mainAxisExtent: 88,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final isSalesCard = card.title.contains('Sales');
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(40)),
          ),
          child: InkWell(
            onTap: isSalesCard ? () => context.push('/sales/analytics') : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: card.color.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(card.icon, color: card.color, size: 22),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.value,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.title,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 2
        : ResponsiveLayout.isTablet(context)
            ? 3
            : 6;

    final actions = [
      _ActionData('Add Employee', Icons.person_add_alt_1_rounded, Colors.blue, () => context.push('/employees/add')),
      _ActionData('Add Purchase', Icons.add_shopping_cart_rounded, Colors.teal, () => context.push('/purchase/add')),
      _ActionData('Add Production', Icons.add_box_rounded, Colors.purple, () => context.push('/production/create')),
      _ActionData('Add Sale', Icons.point_of_sale_rounded, Colors.amber, () => context.push('/sales/add')),
      _ActionData('Inventory', Icons.inventory_2_rounded, Colors.red, () => context.push('/inventory')),
      _ActionData('Attendance', Icons.fingerprint_rounded, Colors.green, () => context.push('/attendance')),
      _ActionData('Machines', Icons.settings_rounded, Colors.cyan, () => context.push('/machines')),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p12,
        mainAxisSpacing: AppSizes.p12,
        childAspectRatio: 1.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final act = actions[index];
        return Card(
          elevation: 0,
          color: act.color.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: act.color.withAlpha(60)),
          ),
          child: InkWell(
            onTap: act.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(act.icon, color: act.color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    act.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(BuildContext context, ThemeData theme, List<ActivityItem> activities) {
    if (activities.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withAlpha(40)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: Text('No recent activity records found.'),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withAlpha(45)),
            itemBuilder: (context, index) {
              final act = activities[index];

              // Format relative or friendly time
              final timeStr = '${act.dateTime.hour.toString().padLeft(2, '0')}:${act.dateTime.minute.toString().padLeft(2, '0')}';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 4),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: act.color.withAlpha(30),
                  child: Icon(act.icon, color: act.color, size: 18),
                ),
                title: Text(
                  act.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              );
            },
          ),
          Divider(height: 1, color: theme.dividerColor.withAlpha(45)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton(
              onPressed: () => context.push('/activity'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All Activity',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _StatCardData(this.title, this.value, this.icon, this.color);
}

class _ActionData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionData(this.title, this.icon, this.color, this.onTap);
}
