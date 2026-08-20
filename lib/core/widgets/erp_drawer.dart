import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';

class ERPDrawer extends ConsumerWidget {
  const ERPDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? AppStrings.roleEmployee;
    final userName = authState.userName ?? 'User';
    final company = authState.selectedCompany ?? 'Apex Industries';

    // Get current path to highlight active state
    final currentRoute = GoRouterState.of(context).uri.path;

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Custom Drawer Header with User details
            Container(
              padding: const EdgeInsets.only(top: 48, left: AppSizes.p24, right: AppSizes.p24, bottom: AppSizes.p20),
              color: isDark ? theme.colorScheme.surface : AppColors.primaryLight,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          company,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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
  
            // Drawer Navigation Items List
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildNavigationGroups(context, role, currentRoute, isDark, theme, ref),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNavigationGroups(
    BuildContext context,
    String role,
    String currentRoute,
    bool isDark,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final List<Widget> children = [];

    // MAIN Section
    final mainItems = <_NavItem>[];
    mainItems.add(const _NavItem(AppStrings.navDashboard, Icons.home_rounded, '/-dashboard')); // matches dashboard paths like /owner-dashboard
    
    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      mainItems.add(const _NavItem(AppStrings.navEmployees, Icons.people_rounded, '/employees'));
    }

    if (role == 'Owner') {
      mainItems.add(const _NavItem(AppStrings.navAttendance, Icons.access_time_filled_rounded, '/attendance'));
      mainItems.add(const _NavItem(AppStrings.navTasks, Icons.assignment_rounded, '/tasks'));
      mainItems.add(const _NavItem('Leaves Portal', Icons.time_to_leave_rounded, '/leaves'));
    } else if (role == 'HR' || role == 'Supervisor') {
      mainItems.add(const _NavItem(AppStrings.navAttendance, Icons.access_time_filled_rounded, '/attendance'));
      mainItems.add(const _NavItem(AppStrings.navTasks, Icons.assignment_rounded, '/tasks'));
      mainItems.add(const _NavItem(AppStrings.navLeaveApproval, Icons.approval_rounded, '/leaves'));
    } else {
      // Employee
      mainItems.add(const _NavItem('My Attendance', Icons.fingerprint_rounded, '/attendance'));
      mainItems.add(const _NavItem('My Tasks', Icons.checklist_rounded, '/tasks'));
      mainItems.add(const _NavItem('Apply Leave', Icons.time_to_leave_rounded, '/leaves'));
    }

    if (mainItems.isNotEmpty) {
      children.add(_buildSectionHeader('MAIN'));
      children.addAll(mainItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
      children.add(const SizedBox(height: 12));
    }

    // OPERATIONS Section
    final operationsItems = <_NavItem>[];
    operationsItems.add(const _NavItem(AppStrings.navProduction, Icons.precision_manufacturing_rounded, '/production'));

    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      operationsItems.add(const _NavItem('Machines', Icons.settings_rounded, '/machines'));
      operationsItems.add(const _NavItem('Tooling', Icons.build_rounded, '/tooling'));
      operationsItems.add(const _NavItem('Drawings', Icons.architecture_rounded, '/drawings'));
      operationsItems.add(const _NavItem('Programs', Icons.code_rounded, '/programs'));
      operationsItems.add(const _NavItem(AppStrings.navInventory, Icons.inventory_2_rounded, '/inventory'));
      operationsItems.add(const _NavItem(AppStrings.navPurchase, Icons.shopping_cart_rounded, '/purchase'));
      operationsItems.add(const _NavItem(AppStrings.navSales, Icons.sell_rounded, '/sales'));
      operationsItems.add(const _NavItem('Billing', Icons.receipt_long_rounded, '/billing'));
    }

    if (operationsItems.isNotEmpty) {
      children.add(_buildSectionHeader('OPERATIONS'));
      children.addAll(operationsItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
      children.add(const SizedBox(height: 12));
    }

    // MANAGEMENT Section
    final managementItems = <_NavItem>[];
    if (role == 'Owner') {
      managementItems.add(const _NavItem(AppStrings.navReports, Icons.analytics_rounded, '/reports'));
      managementItems.add(const _NavItem(AppStrings.navDocuments, Icons.folder_shared_rounded, '/documents'));
      managementItems.add(const _NavItem(AppStrings.navNotifications, Icons.notifications_active_rounded, '/notifications'));
      managementItems.add(const _NavItem('Comparison', Icons.compare_arrows_rounded, '/comparison'));
    } else if (role == 'HR' || role == 'Supervisor') {
      managementItems.add(const _NavItem(AppStrings.navReports, Icons.assignment_rounded, '/reports'));
      managementItems.add(const _NavItem(AppStrings.navNotifications, Icons.notifications_active_rounded, '/notifications'));
    } else {
      // Employee
      managementItems.add(const _NavItem(AppStrings.navNotifications, Icons.notifications_rounded, '/notifications'));
    }

    if (managementItems.isNotEmpty) {
      children.add(_buildSectionHeader('MANAGEMENT'));
      children.addAll(managementItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
      children.add(const SizedBox(height: 12));
    }

    // ACCOUNT Section
    final accountItems = <_NavItem>[];
    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      accountItems.add(const _NavItem(AppStrings.navSettings, Icons.settings_applications_rounded, '/settings'));
    } else {
      // Employee
      accountItems.add(const _NavItem(AppStrings.navProfile, Icons.person_rounded, '/settings')); // Profile goes to settings route
    }

    children.add(_buildSectionHeader('ACCOUNT'));
    children.addAll(accountItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));

    // Logout
    final logoutColor = AppColors.error;
    children.add(
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: 0),
        dense: true,
        leading: Icon(Icons.logout_rounded, color: logoutColor, size: 22),
        title: const Text(
          AppStrings.logout,
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onTap: () {
          ref.read(authProvider.notifier).logout();
        },
      ),
    );

    children.add(const SizedBox(height: AppSizes.p16));
    children.add(
      Center(
        child: Text(
          'Manufacturing ERP v1.0.0',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
            fontSize: 11,
          ),
        ),
      ),
    );

    return children;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.p24, top: 12, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    _NavItem item,
    String currentRoute,
    bool isDark,
    ThemeData theme,
    String role,
  ) {
    final bool isSelected;
    if (item.route == '/-dashboard') {
      isSelected = currentRoute.endsWith('-dashboard');
    } else {
      isSelected = currentRoute.startsWith(item.route);
    }

    final Color iconColor;
    final Color textColor;
    final Color? tileColor;

    if (isSelected) {
      iconColor = isDark ? theme.colorScheme.primary : AppColors.primaryLight;
      textColor = isDark ? theme.colorScheme.primary : AppColors.primaryLight;
      tileColor = isDark ? theme.colorScheme.primary.withOpacity(0.08) : AppColors.primaryLight.withOpacity(0.08);
    } else {
      iconColor = isDark ? Colors.white70 : Colors.grey.shade600;
      textColor = isDark ? Colors.white.withOpacity(0.9) : Colors.grey.shade800;
      tileColor = null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: tileColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(
          item.icon,
          color: iconColor,
          size: 22,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
        dense: true,
        onTap: () {
          // Close the drawer if it's a mobile drawer
          // check if we are in a mobile environment or desktop
          final ScaffoldState? scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            Navigator.of(context).pop();
          }

          if (item.title == AppStrings.navDashboard) {
            // Dashboard navigation handles its own routing based on role or is resolved
            if (role == 'Owner') {
              context.go('/owner-dashboard');
            } else if (role == 'HR' || role == 'Supervisor') {
              context.go('/hr-dashboard');
            } else {
              context.go('/employee-dashboard');
            }
          } else if (item.title == AppStrings.navEmployees) {
            context.push('/employees');
          } else if (item.title == AppStrings.navAttendance || item.title == 'My Attendance') {
            context.push('/attendance');
          } else if (item.title == AppStrings.navTasks) {
            context.push('/tasks');
          } else if (item.title == 'My Tasks') {
            context.push('/tasks/my-tasks');
          } else if (item.title == AppStrings.navLeaveApproval || item.title == 'Leaves Portal' || item.title == 'Apply Leave') {
            context.push('/leaves');
          } else if (item.title == AppStrings.navNotifications) {
            context.push('/notifications');
          } else if (item.title == 'Machines') {
            context.push('/machines');
          } else if (item.title == 'Tooling') {
            context.push('/tooling');
          } else if (item.title == 'Drawings') {
            context.push('/drawings');
          } else if (item.title == 'Programs') {
            context.push('/programs');
          } else if (item.title == AppStrings.navInventory) {
            context.push('/inventory');
          } else if (item.title == AppStrings.navProduction) {
            context.push('/production');
          } else if (item.title == AppStrings.navPurchase) {
            context.push('/purchase');
          } else if (item.title == AppStrings.navSales) {
            context.push('/sales');
          } else if (item.title == 'Billing') {
            context.push('/billing');
          } else if (item.title == 'Comparison') {
            context.push('/comparison');
          } else if (item.title == AppStrings.navSettings || item.title == AppStrings.navProfile) {
            context.push('/settings');
          } else if (item.title == AppStrings.navReports || item.title == AppStrings.navAnalytics) {
            context.push('/reports');
          } else {
            _showTodoDialog(context, item.title, role);
          }
        },
      ),
    ),);
  }

  void _showTodoDialog(BuildContext context, String featureName, String role) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('Feature: $featureName'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role: $role'),
              const SizedBox(height: 8),
              const Text(
                'This screen is a placeholder. The module and corresponding business logic will be integrated in future phases.',
              ),
              const SizedBox(height: 12),
              const Text(
                'TODO: Add Firebase database synchronizers, state logic and concrete UI.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final String route;

  const _NavItem(this.title, this.icon, this.route);
}
