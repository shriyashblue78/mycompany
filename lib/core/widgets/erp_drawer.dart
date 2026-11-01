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
import '../../features/subscription/presentation/providers/subscription_provider.dart';

class ERPDrawer extends ConsumerStatefulWidget {
  const ERPDrawer({super.key});

  /// Preserved scroll position across screen navigations
  static double savedScrollOffset = 0.0;

  @override
  ConsumerState<ERPDrawer> createState() => _ERPDrawerState();
}

class _ERPDrawerState extends ConsumerState<ERPDrawer> {
  late ScrollController _scrollController;
  final GlobalKey _selectedItemKey = GlobalKey();
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: ERPDrawer.savedScrollOffset,
      keepScrollOffset: false,
    );
    _scheduleScrollRestoration();
  }

  void _scheduleScrollRestoration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) return;
      _restoreScrollPosition();

      // If maxScrollExtent is still 0 during layout, retry once after layout stabilizes
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent == 0) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && !_isDisposing) {
            _restoreScrollPosition();
          }
        });
      }
    });
  }

  void _restoreScrollPosition() {
    if (!mounted || _isDisposing || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (ERPDrawer.savedScrollOffset > 0 && maxScroll > 0) {
      final target = ERPDrawer.savedScrollOffset.clamp(0.0, maxScroll);
      if ((_scrollController.offset - target).abs() > 1.0) {
        _scrollController.jumpTo(target);
      }
    } else if (_selectedItemKey.currentContext != null) {
      Scrollable.ensureVisible(
        _selectedItemKey.currentContext!,
        alignment: 0.3,
      );
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_isDisposing) return false;
                  if (notification is ScrollUpdateNotification) {
                    final pixels = notification.metrics.pixels;
                    if (notification.dragDetails != null) {
                      ERPDrawer.savedScrollOffset = pixels.clamp(0.0, notification.metrics.maxScrollExtent);
                    } else if (pixels > 0) {
                      ERPDrawer.savedScrollOffset = pixels;
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildNavigationGroups(context, role, currentRoute, isDark, theme, ref),
                    ),
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
    final subAsync = ref.watch(currentCompanySubscriptionProvider);

    // Show Expiry Warning Banner if expiring soon or expired
    subAsync.whenData((sub) {
      if (sub != null && (sub.isExpiringSoon || sub.isExpired)) {
        children.add(
          GestureDetector(
            onTap: () => context.push('/subscription/plans'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sub.isExpired ? Colors.red.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sub.isExpired ? Colors.red : Colors.amber.shade700, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(
                    sub.isExpired ? Icons.error_outline_rounded : Icons.timer_outlined,
                    color: sub.isExpired ? Colors.red : Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.isExpired ? 'Subscription Expired' : 'Subscription Expiring Soon',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: sub.isExpired ? Colors.red : Colors.amber.shade900,
                          ),
                        ),
                        Text(
                          '${sub.remainingTimeFormatted} • Tap to Renew',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      }
    });

    bool isModuleEnabled(String module) {
      if (role == 'super_admin') return true;
      if (module == CompanyModules.inwardOutward || module == CompanyModules.billing) {
        return authState.enabledModules.contains('inward_outward') ||
            authState.enabledModules.contains('billing');
      }
      return authState.enabledModules.contains(module);
    }

    bool hasProjectTrackerAccess(UserModel? user) {
      return ProjectTrackerConfig.hasAccess(user?.role, user?.department);
    }

    // MAIN Section
    final mainItems = <_NavItem>[];
    if (role != 'Accountant') {
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
      if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
        mainItems.add(_NavItem(AppStrings.navAttendance, Icons.access_time_filled_rounded, '/attendance', isLocked: attendanceLocked));
      } else {
        mainItems.add(_NavItem('My Attendance', Icons.fingerprint_rounded, '/attendance', isLocked: attendanceLocked));
      }

      final tasksLocked = !isModuleEnabled(CompanyModules.tasks);
      if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
        mainItems.add(_NavItem(AppStrings.navTasks, Icons.assignment_rounded, '/tasks', isLocked: tasksLocked));
      } else {
        mainItems.add(_NavItem('My Tasks', Icons.checklist_rounded, '/tasks/my-tasks', isLocked: tasksLocked));
      }

      final leavesLocked = !isModuleEnabled(CompanyModules.leaves);
      if (role == 'Owner') {
        mainItems.add(_NavItem('Leaves Portal', Icons.time_to_leave_rounded, '/leaves', isLocked: leavesLocked));
      } else if (role == 'HR' || role == 'Supervisor') {
        mainItems.add(_NavItem(AppStrings.navLeaveApproval, Icons.approval_rounded, '/leaves', isLocked: leavesLocked));
      } else {
        mainItems.add(_NavItem('Apply Leave', Icons.time_to_leave_rounded, '/leaves', isLocked: leavesLocked));
      }
    }

    if (mainItems.isNotEmpty) {
      children.add(_buildSectionHeader('MAIN'));
      children.addAll(mainItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
      children.add(const SizedBox(height: 12));
    }

    // OPERATIONS Section
    final operationsItems = <_NavItem>[];

    if (role != 'Accountant') {
      operationsItems.add(_NavItem(
        AppStrings.navProduction,
        Icons.precision_manufacturing_rounded,
        '/production',
        isLocked: !isModuleEnabled(CompanyModules.production),
      ));
    }

    if (role == 'Owner' || role == 'HR' || role == 'Supervisor') {
      operationsItems.add(_NavItem('Machines', Icons.settings_rounded, '/machines', isLocked: !isModuleEnabled(CompanyModules.machines)));
      operationsItems.add(_NavItem('Tooling', Icons.build_rounded, '/tooling', isLocked: !isModuleEnabled(CompanyModules.tooling)));
      operationsItems.add(_NavItem('Drawings', Icons.architecture_rounded, '/drawings', isLocked: !isModuleEnabled(CompanyModules.drawings)));
      operationsItems.add(_NavItem('Programs', Icons.code_rounded, '/programs', isLocked: !isModuleEnabled(CompanyModules.programs)));
      operationsItems.add(_NavItem(AppStrings.navInventory, Icons.inventory_2_rounded, '/inventory', isLocked: !isModuleEnabled(CompanyModules.inventory)));
      operationsItems.add(_NavItem('Inward / Outward', Icons.swap_horiz_rounded, '/inward-outward', isLocked: !isModuleEnabled(CompanyModules.inwardOutward)));
    }

    if (role == 'Owner' || role == 'Accountant') {
      operationsItems.add(_NavItem(AppStrings.navPurchase, Icons.shopping_cart_rounded, '/purchase', isLocked: !isModuleEnabled(CompanyModules.purchase)));
      operationsItems.add(_NavItem(AppStrings.navSales, Icons.sell_rounded, '/sales', isLocked: !isModuleEnabled(CompanyModules.sales)));
      operationsItems.add(const _NavItem('Tally Integration', Icons.receipt_long_rounded, '/tally'));
    }

    if (role != 'Accountant' && hasProjectTrackerAccess(authState.user)) {
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

    // MASTERS Section
    final mastersItems = <_NavItem>[];
    if (role == 'Owner' || role == 'Accountant') {
      mastersItems.add(const _NavItem('Party Master', Icons.business_rounded, '/parties'));
      mastersItems.add(const _NavItem('Category Master', Icons.category_rounded, '/masters/categories'));
      mastersItems.add(const _NavItem('Group Master', Icons.folder_special_rounded, '/masters/groups'));
      mastersItems.add(const _NavItem('Update Item Group', Icons.edit_note_rounded, '/masters/update-item-group'));
      mastersItems.add(const _NavItem('Unit Master', Icons.straighten_rounded, '/masters/units'));
      mastersItems.add(const _NavItem('Item Master', Icons.inventory_2_rounded, '/masters/items'));
      mastersItems.add(const _NavItem('Tax Master', Icons.account_balance_rounded, '/masters/taxes'));
      mastersItems.add(const _NavItem('HSN/SAC Master', Icons.tag_rounded, '/masters/hsn-sac'));
      mastersItems.add(const _NavItem('Process Master', Icons.alt_route_rounded, '/masters/processes'));
      mastersItems.add(const _NavItem('Transaction Type Master', Icons.swap_horiz_rounded, '/masters/transaction-types'));
      mastersItems.add(const _NavItem('Rejection Reason Master', Icons.assignment_late_rounded, '/masters/rejection-reasons'));
      mastersItems.add(const _NavItem('Opening Balance Entry', Icons.account_balance_wallet_rounded, '/masters/opening-balance'));
      mastersItems.add(const _NavItem('PDI Master', Icons.fact_check_rounded, '/masters/pdi'));
      mastersItems.add(const _NavItem('State Master', Icons.location_on_rounded, '/masters/states'));
      mastersItems.add(const _NavItem('Clearance Type Master', Icons.verified_user_rounded, '/masters/clearance-types'));
      mastersItems.add(const _NavItem('Update HSN/SAC', Icons.tune_rounded, '/masters/update-hsn-sac'));
    }

    if (mastersItems.isNotEmpty) {
      children.add(_buildSectionHeader('MASTERS'));
      children.addAll(mastersItems.map((item) => _buildTile(context, item, currentRoute, isDark, theme, role)));
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
    managementItems.add(_NavItem(AppStrings.navNotifications, Icons.notifications_rounded, '/notifications', isLocked: notificationsLocked));

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
    if (role == 'Owner' || role == 'HR' || role == 'super_admin') {
      accountItems.add(const _NavItem('Subscription & Plans', Icons.stars_rounded, '/subscription/plans'));
    }
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
          ERPDrawer.savedScrollOffset = 0.0;
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
    if (item.route.isEmpty) {
      isSelected = false;
    } else if (item.route == '/-dashboard') {
      isSelected = currentRoute.endsWith('-dashboard');
    } else if (item.route == '/tasks') {
      isSelected = currentRoute == '/tasks';
    } else {
      isSelected = currentRoute == item.route || currentRoute.startsWith('${item.route}/');
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
      key: isSelected ? _selectedItemKey : null,
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
            // Snapshot scroll position before any navigation or drawer dismiss
            if (_scrollController.hasClients && _scrollController.offset > 0) {
              ERPDrawer.savedScrollOffset = _scrollController.offset;
            }

            final ScaffoldState? scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.isDrawerOpen) {
              Navigator.of(context).pop();
            }

            if (item.isLocked) {
              context.push('/feature-locked?module=${item.title}');
              return;
            }

            // If already on this exact item, stay fixed and do nothing
            if (isSelected) {
              return;
            }

            if (item.route == '/-dashboard') {
              if (role == 'Owner') {
                context.go('/owner-dashboard');
              } else if (role == 'HR' || role == 'Supervisor') {
                context.go('/hr-dashboard');
              } else {
                context.go('/employee-dashboard');
              }
            } else if (item.route.isNotEmpty) {
              context.go(item.route);
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
