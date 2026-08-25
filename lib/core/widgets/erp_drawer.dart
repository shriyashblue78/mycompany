import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/models/company_modules.dart';
import '../../features/project_tracker/domain/models/project_tracker_config.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';
import '../../features/auth/domain/models/user_model.dart';

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

    final currentRoute = GoRouterState.of(context).uri.path;

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
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
    final authState = ref.watch(authProvider);

    bool isModuleEnabled(String module) {
      if (role == 'super_admin') return true;
      return authState.enabledModules.contains(module);
    }

    bool hasProjectTrackerAccess(UserModel? user) {
      return ProjectTrackerConfig.hasAccess(user?.role, user?.department);
    }

    // MAIN Section
    final mainItems = <_NavItem>[];
    mainItems.add(const _NavItem(AppStrings.navDashboard, Icons.home_rounded, '/-dashboard'));

    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      mainItems.add(_NavItem(
        AppStrings.navEmployees,
        Icons.people_rounded,
        '/employees',
        isLocked: !isModuleEnabled(CompanyModules.employees),
      ));
    }

    final attendanceLocked = !isModuleEnabled(CompanyModules.attendance);
    if (role == 'Owner') {
      mainItems.add(_NavItem(AppStrings.navAttendance, Icons.access_time_filled_rounded, '/attendance', isLocked: attendanceLocked));
    } else if (role == 'HR' || role == 'Supervisor') {
      mainItems.add(_NavItem(AppStrings.navAttendance, Icons.access_time_filled_rounded, '/attendance', isLocked: attendanceLocked));
    } else {
      mainItems.add(_NavItem('My Attendance', Icons.fingerprint_rounded, '/attendance', isLocked: attendanceLocked));
    }

    final tasksLocked = !isModuleEnabled(CompanyModules.tasks);
    if (role == 'Owner') {
      mainItems.add(_NavItem(AppStrings.navTasks, Icons.assignment_rounded, '/tasks', isLocked: tasksLocked));
    } else if (role == 'HR' || role == 'Supervisor') {
      mainItems.add(_NavItem(AppStrings.navTasks, Icons.assignment_rounded, '/tasks', isLocked: tasksLocked));
    } else {
      mainItems.add(_NavItem('My Tasks', Icons.checklist_rounded, '/tasks', isLocked: tasksLocked));
    }

    final leavesLocked = !isModuleEnabled(CompanyModules.leaves);
    if (role == 'Owner') {
      mainItems.add(_NavItem('Leaves Portal', Icons.time_to_leave_rounded, '/leaves', isLocked: leavesLocked));
    } else if (role == 'HR' || role == 'Supervisor') {
      mainItems.add(_NavItem(AppStrings.navLeaveApproval, Icons.approval_rounded, '/leaves', isLocked: leavesLocked));
    } else {
      mainItems.add(_NavItem('Apply Leave', Icons.time_to_leave_rounded, '/leaves', isLocked: leavesLocked));
    }

    if (mainItems.isNotEmpty) {
      children.add(_buildSectionHeader('MAIN'));
      children.addAll(mainItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
      children.add(const SizedBox(height: 12));
    }

    // OPERATIONS Section
    final operationsItems = <_NavItem>[];

    operationsItems.add(_NavItem(
      AppStrings.navProduction,
      Icons.precision_manufacturing_rounded,
      '/production',
      isLocked: !isModuleEnabled(CompanyModules.production),
    ));

    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      operationsItems.add(_NavItem('Machines', Icons.settings_rounded, '/machines', isLocked: !isModuleEnabled(CompanyModules.machines)));
      operationsItems.add(_NavItem('Tooling', Icons.build_rounded, '/tooling', isLocked: !isModuleEnabled(CompanyModules.tooling)));
      operationsItems.add(_NavItem('Drawings', Icons.architecture_rounded, '/drawings', isLocked: !isModuleEnabled(CompanyModules.drawings)));
      operationsItems.add(_NavItem('Programs', Icons.code_rounded, '/programs', isLocked: !isModuleEnabled(CompanyModules.programs)));
      operationsItems.add(_NavItem(AppStrings.navInventory, Icons.inventory_2_rounded, '/inventory', isLocked: !isModuleEnabled(CompanyModules.inventory)));
      operationsItems.add(_NavItem(AppStrings.navPurchase, Icons.shopping_cart_rounded, '/purchase', isLocked: !isModuleEnabled(CompanyModules.purchase)));
      operationsItems.add(_NavItem(AppStrings.navSales, Icons.sell_rounded, '/sales', isLocked: !isModuleEnabled(CompanyModules.sales)));
      operationsItems.add(_NavItem('Billing', Icons.receipt_long_rounded, '/billing', isLocked: !isModuleEnabled(CompanyModules.billing)));
    }

    if (hasProjectTrackerAccess(authState.user)) {
      operationsItems.add(_NavItem(
        'Project Tracker',
        Icons.assignment_turned_in_rounded,
        '/project-tracker',
        isLocked: !isModuleEnabled(CompanyModules.projectTracker),
      ));
    }

    if (operationsItems.isNotEmpty) {
      children.add(_buildSectionHeader('OPERATIONS'));
      children.addAll(operationsItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
      children.add(const SizedBox(height: 12));
    }

    // MANAGEMENT Section
    final managementItems = <_NavItem>[];

    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      final reportsLocked = !isModuleEnabled(CompanyModules.reports);
      managementItems.add(_NavItem(
        AppStrings.navReports,
        role == 'Owner' ? Icons.analytics_rounded : Icons.assignment_rounded,
        '/reports',
        isLocked: reportsLocked,
      ));
    }

    if (role == 'Owner') {
      managementItems.add(_NavItem(
        AppStrings.navDocuments,
        Icons.folder_shared_rounded,
        '/documents',
        isLocked: !isModuleEnabled(CompanyModules.documents),
      ));
    }

    final notificationsLocked = !isModuleEnabled(CompanyModules.notifications);
    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      managementItems.add(_NavItem(AppStrings.navNotifications, Icons.notifications_active_rounded, '/notifications', isLocked: notificationsLocked));
    } else {
      managementItems.add(_NavItem(AppStrings.navNotifications, Icons.notifications_rounded, '/notifications', isLocked: notificationsLocked));
    }

    if (role == 'Owner') {
      managementItems.add(_NavItem(
        'Comparison',
        Icons.compare_arrows_rounded,
        '/comparison',
        isLocked: !isModuleEnabled(CompanyModules.comparison),
      ));
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
      accountItems.add(const _NavItem(AppStrings.navProfile, Icons.person_rounded, '/settings'));
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

    if (item.isLocked) {
      iconColor = theme.disabledColor;
      textColor = theme.disabledColor;
      tileColor = null;
    } else if (isSelected) {
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
              fontWeight: isSelected && !item.isLocked ? FontWeight.bold : FontWeight.w500,
              color: textColor,
            ),
          ),
          trailing: item.isLocked
              ? Icon(
                  Icons.lock_outline_rounded,
                  color: theme.disabledColor,
                  size: 16,
                )
              : null,
          dense: true,
          onTap: () {
            final ScaffoldState? scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.isDrawerOpen) {
              Navigator.of(context).pop();
            }

            if (item.isLocked) {
              context.push('/feature-locked?module=${item.title}');
              return;
            }

            if (item.title == AppStrings.navDashboard) {
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
            } else if (item.title == 'Project Tracker') {
              context.push('/project-tracker');
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
      ),
    );
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
  final bool isLocked;

  const _NavItem(this.title, this.icon, this.route, {this.isLocked = false});
}
