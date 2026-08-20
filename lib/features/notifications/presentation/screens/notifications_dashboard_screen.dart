import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

class NotificationsDashboardScreen extends ConsumerWidget {
  const NotificationsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(notificationStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';
    final companyName = authState.selectedCompany ?? 'Apex Industries';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('$companyName - Notifications'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading notifications: $err')),
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
                      _buildHeaderCard(context, theme, role, isManager, isDark),
                      const SizedBox(height: AppSizes.p24),

                      // Stats Grid
                      Text(
                        'Notification Metrics',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildStatsGrid(context, stats),
                      const SizedBox(height: AppSizes.p24),

                      // Quick Actions
                      Text(
                        'Actions',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildActionsGrid(context, isManager),
                      const SizedBox(height: AppSizes.p24),

                      // Recent Announcements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Company Announcements',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () => context.push('/notifications/list'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _buildRecentAnnouncements(context, ref, stats.recentAnnouncements, isDark),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/notifications/create'),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('New Announcement'),
              backgroundColor: theme.colorScheme.primary,
            )
          : null,
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ThemeData theme,
    String role,
    bool isManager,
    bool isDark,
  ) {
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
                    'COMMUNICATIONS CENTER',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  isManager ? 'Control & Broadcasting Console' : 'Announcements & Updates',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  isManager
                      ? 'Create, edit, pin, and target critical announcements to departments or individual employees.'
                      : 'Stay informed with real-time task logs, HR leaves, system notifications, and official announcements.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p16),
          Icon(
            Icons.notifications_active_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, NotificationStats stats) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 3
            : 3;

    final cards = [
      _StatItem('Total Messages', stats.total.toString(), Icons.mail_rounded, AppColors.info),
      _StatItem('Unread Messages', stats.unread.toString(), Icons.mark_chat_unread_rounded, AppColors.warning),
      _StatItem('Pinned Announcements', stats.pinned.toString(), Icons.push_pin_rounded, AppColors.success),
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

  Widget _buildActionsGrid(BuildContext context, bool isManager) {
    final List<Widget> actions = [
      _buildActionCard(
        context,
        'Notification List',
        'Search and filter all your notifications.',
        Icons.list_alt_rounded,
        AppColors.info,
        () => context.push('/notifications/list'),
      ),
    ];

    if (isManager) {
      actions.add(
        _buildActionCard(
          context,
          'Create Announcement',
          'Draft and broadcast a new message.',
          Icons.add_alert_rounded,
          AppColors.warning,
          () => context.push('/notifications/create'),
        ),
      );
      actions.add(
        _buildActionCard(
          context,
          'Announcement History',
          'Edit, delete, and check sent records.',
          Icons.history_rounded,
          AppColors.success,
          () => context.push('/notifications/history'),
        ),
      );
    }

    final columns = ResponsiveLayout.isMobile(context)
        ? 1
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
                backgroundColor: color.withAlpha(26),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withAlpha(179)),
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

  Widget _buildRecentAnnouncements(
    BuildContext context,
    WidgetRef ref,
    List<NotificationWithReadState> announcements,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    if (announcements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withAlpha(77),
                ),
                const SizedBox(height: AppSizes.p12),
                Text(
                  'No recent announcements found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: announcements.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final item = announcements[index];
        final notif = item.notification;

        return Card(
          margin: EdgeInsets.zero,
          elevation: item.isRead ? 0 : 2,
          color: item.isRead
              ? (isDark ? theme.colorScheme.surface : Colors.grey.shade50)
              : (isDark ? theme.colorScheme.surface.withAlpha(200) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(
              color: item.isRead
                  ? Colors.transparent
                  : theme.colorScheme.primary.withAlpha(51),
              width: 1.5,
            ),
          ),
          child: ListTile(
            onTap: () {
              if (!item.isRead) {
                final authState = ref.read(authProvider);
                if (authState.user != null) {
                  ref.read(notificationRepositoryProvider).markAsRead(
                        authState.user!.companyId,
                        authState.user!.employeeId,
                        notif.notificationId,
                      );
                }
              }
              context.push('/notifications/${notif.notificationId}');
            },
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: _getPriorityColor(notif.priority).withAlpha(38),
                  child: Icon(
                    notif.isPinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
                    color: _getPriorityColor(notif.priority),
                  ),
                ),
                if (!item.isRead)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              notif.title,
              style: TextStyle(
                fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notif.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'By ${notif.createdByName}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(notif.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return AppColors.error;
      case 'High':
        return AppColors.warning;
      case 'Medium':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(this.title, this.value, this.icon, this.color);
}
