import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SuperAdminDrawer extends ConsumerWidget {
  const SuperAdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final userName = authState.userName ?? 'Super Admin';
    final role = authState.selectedRole ?? 'super_admin';

    final navItems = [
      _SAItem('Dashboard', Icons.dashboard_rounded, '/super-admin', true),
      _SAItem('Companies', Icons.business_rounded, '/super-admin/companies', true),
      _SAItem('Analytics', Icons.analytics_rounded, '/super-admin/analytics', false),
      _SAItem('Settings', Icons.settings_rounded, '/super-admin/settings', false),
    ];

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            accountName: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  role == 'super_admin' ? 'ERP Super Admin' : role,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Text(
                  'ERP Control Panel',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                return ListTile(
                  leading: Icon(item.icon, color: item.enabled ? null : Colors.grey),
                  title: Text(
                    item.title,
                    style: TextStyle(color: item.enabled ? null : Colors.grey),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(); // Close drawer
                    if (item.enabled) {
                      context.push(item.route);
                    } else {
                      _showPlaceholderDialog(context, item.title);
                    }
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
          const SizedBox(height: AppSizes.p16),
        ],
      ),
    );
  }

  void _showPlaceholderDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$title - Preview Mode'),
          content: Text('The $title panel is currently under construction and will be fully integrated in the next rollout phase.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _SAItem {
  final String title;
  final IconData icon;
  final String route;
  final bool enabled;

  const _SAItem(this.title, this.icon, this.route, this.enabled);
}
