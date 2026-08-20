import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/hr_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/employee_dashboard_screen.dart';
import '../../features/employee/domain/models/employee_model.dart';
import '../../features/employee/presentation/screens/employee_list_screen.dart';
import '../../features/employee/presentation/screens/employee_detail_screen.dart';
import '../../features/employee/presentation/screens/employee_form_screen.dart';
import '../../features/employee/presentation/screens/employee_performance_screen.dart';
import '../../features/attendance/presentation/screens/attendance_dashboard_screen.dart';
import '../../features/attendance/presentation/screens/mark_attendance_screen.dart';
import '../../features/attendance/presentation/screens/todays_attendance_screen.dart';
import '../../features/attendance/presentation/screens/attendance_history_screen.dart';
import '../../features/attendance/presentation/screens/monthly_attendance_screen.dart';
import '../../features/attendance/presentation/screens/employee_attendance_detail_screen.dart';
import '../../features/attendance/presentation/screens/search_attendance_screen.dart';
import '../../features/tasks/domain/models/task_model.dart';
import '../../features/tasks/presentation/screens/task_dashboard_screen.dart';
import '../../features/tasks/presentation/screens/task_list_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../features/tasks/presentation/screens/task_form_screen.dart';
import '../../features/tasks/presentation/screens/task_my_tasks_screen.dart';
import '../../features/tasks/presentation/screens/task_completed_screen.dart';
import '../../features/leaves/presentation/screens/leave_dashboard_screen.dart';
import '../../features/leaves/presentation/screens/apply_leave_screen.dart';
import '../../features/leaves/presentation/screens/my_leave_history_screen.dart';
import '../../features/leaves/presentation/screens/leave_detail_screen.dart';
import '../../features/leaves/presentation/screens/company_leave_requests_screen.dart';
import '../../features/leaves/presentation/screens/leave_approval_screen.dart';
import '../../features/leaves/presentation/screens/leave_calendar_screen.dart';
import '../../features/notifications/domain/models/notification_model.dart';
import '../../features/notifications/presentation/screens/notifications_dashboard_screen.dart';
import '../../features/notifications/presentation/screens/notification_list_screen.dart';
import '../../features/notifications/presentation/screens/notification_detail_screen.dart';
import '../../features/notifications/presentation/screens/create_announcement_screen.dart';
import '../../features/notifications/presentation/screens/announcement_history_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_dashboard_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_company_list_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_company_detail_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_create_company_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_edit_company_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_company_settings_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_owner_detail_screen.dart';
import '../../features/inventory/presentation/screens/inventory_list_screen.dart';
import '../../features/inventory/presentation/screens/inventory_form_screen.dart';
import '../../features/inventory/presentation/screens/inventory_detail_screen.dart';
import '../../features/production/domain/models/production_model.dart';
import '../../features/production/presentation/screens/production_list_screen.dart';
import '../../features/production/presentation/screens/production_form_screen.dart';
import '../../features/production/presentation/screens/production_detail_screen.dart';
import '../../features/billing/presentation/screens/billing_placeholder_screen.dart';
import '../../features/purchase/presentation/screens/purchase_list_screen.dart';
import '../../features/purchase/presentation/screens/purchase_form_screen.dart';
import '../../features/sales/presentation/screens/sales_list_screen.dart';
import '../../features/sales/presentation/screens/sales_form_screen.dart';
import '../../features/sales/presentation/screens/sales_analytics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/reports/presentation/screens/reports_home_screen.dart';
import '../../features/machines/domain/models/machine_model.dart';
import '../../features/machines/presentation/screens/machine_list_screen.dart';
import '../../features/machines/presentation/screens/machine_form_screen.dart';
import '../../features/machines/presentation/screens/machine_detail_screen.dart';
import '../../features/tooling/domain/models/tool_model.dart';
import '../../features/tooling/presentation/screens/tool_list_screen.dart';
import '../../features/tooling/presentation/screens/tool_detail_screen.dart';
import '../../features/tooling/presentation/screens/tool_form_screen.dart';
import '../../features/dashboard/presentation/screens/activity_screen.dart';
import '../../features/dashboard/presentation/screens/comparison_screen.dart';
import '../../features/drawings/presentation/screens/drawing_list_screen.dart';
import '../../features/drawings/presentation/screens/drawing_form_screen.dart';
import '../../features/programs/domain/models/program_model.dart';
import '../../features/programs/presentation/screens/program_list_screen.dart';
import '../../features/programs/presentation/screens/program_form_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Helper to notify GoRouter when Auth state changes
class GoRouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

final routerNotifierProvider = Provider<GoRouterRefreshNotifier>((ref) {
  final notifier = GoRouterRefreshNotifier();
  ref.listen<AuthState>(authProvider, (previous, next) {
    notifier.refresh();
  });
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final currentRoute = state.uri.path;
      final currentAuthState = ref.read(authProvider);

      // Check if user is logged in
      if (!currentAuthState.isLoggedIn) {
        // Not logged in. Redirect to login if not already on splash/login
        if (currentRoute != '/login' && currentRoute != '/splash') {
          return '/login';
        }
        return null;
      }

      // User is logged in. Redirect away from splash/login to correct dashboard
      if (currentRoute == '/login' || currentRoute == '/splash') {
        return _getDashboardRoute(currentAuthState.selectedRole);
      }

      // Enforce role-based access for employee management module
      if (currentRoute.startsWith('/employees')) {
        final role = currentAuthState.selectedRole;
        final employeeId = currentAuthState.user?.employeeId;
        final isOwnPerformance = employeeId != null && 
            currentRoute == '/employees/$employeeId/performance';
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor' && !isOwnPerformance) {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for task creation and editing
      if (currentRoute == '/tasks/create' || (currentRoute.startsWith('/tasks') && currentRoute.endsWith('/edit'))) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for leave approvals/directory
      if (currentRoute == '/leaves/requests' || currentRoute == '/leaves/approval') {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for announcement creation and history
      if (currentRoute == '/notifications/create' || currentRoute == '/notifications/history') {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for reports (Owner and HR only)
      if (currentRoute.startsWith('/reports')) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR') {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for inventory module
      if (currentRoute.startsWith('/inventory')) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
        // Owner only for Add/Edit
        if (currentRoute == '/inventory/add' || currentRoute.contains('/edit/')) {
          if (role != 'Owner') {
            return '/inventory';
          }
        }
      }

      // Enforce role-based access for purchase module
      if (currentRoute.startsWith('/purchase')) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
        // Owner only for Add/Edit
        if (currentRoute == '/purchase/add' || (currentRoute.startsWith('/purchase') && currentRoute.contains('/edit/'))) {
          if (role != 'Owner') {
            return '/purchase';
          }
        }
      }

      // Enforce role-based access for sales module
      if (currentRoute.startsWith('/sales')) {
        final role = currentAuthState.selectedRole;
        
        // Owner and HR only for Sales Analytics
        if (currentRoute.startsWith('/sales/analytics')) {
          if (role != 'Owner' && role != 'HR') {
            return _getDashboardRoute(role);
          }
        } else {
          // General sales list access for Owner, HR, Supervisor
          if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
            return _getDashboardRoute(role);
          }
        }

        // Owner only for Add/Edit
        if (currentRoute == '/sales/add' || (currentRoute.startsWith('/sales') && currentRoute.contains('/edit/'))) {
          if (role != 'Owner') {
            return '/sales';
          }
        }
      }

      // Enforce role-based access for production creation and editing
      if (currentRoute == '/production/create' || (currentRoute.startsWith('/production') && currentRoute.endsWith('/edit'))) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'Supervisor') {
          return '/production';
        }
      }

      // Enforce role-based access for comparison screen (Owner only)
      if (currentRoute.startsWith('/comparison')) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner') {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for activity feed
      if (currentRoute.startsWith('/activity')) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
      }

      // Prevent normal users from accessing super_admin routes
      if (currentRoute.startsWith('/super-admin')) {
        final role = currentAuthState.selectedRole;
        if (role != 'super_admin') {
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for machines
      if (currentRoute.startsWith('/machines')) {
        final role = currentAuthState.selectedRole;
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          if (role == 'super_admin') {
            return '/super-admin';
          }
          return _getDashboardRoute(role);
        }
      }

      // Enforce role-based access for tooling
      if (currentRoute.startsWith('/tooling')) {
        final role = currentAuthState.selectedRole;
        if (role == 'super_admin') {
          return '/super-admin';
        }
        // Employee has View access, but Add/Edit are restricted to Owner, HR, Supervisor.
        if (currentRoute == '/tooling/add' || (currentRoute.startsWith('/tooling/') && currentRoute.endsWith('/edit'))) {
          if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
            return '/tooling';
          }
        }
      }

      // Enforce role-based access for drawings
      if (currentRoute.startsWith('/drawings')) {
        final role = currentAuthState.selectedRole;
        if (role == 'super_admin') {
          return '/super-admin';
        }
        // Employee has no access at all. Allowed only for Owner, HR, Supervisor.
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
        // Upload drawings (/drawings/add) restricted to Owner and HR only.
        if (currentRoute == '/drawings/add') {
          if (role != 'Owner' && role != 'HR') {
            return '/drawings';
          }
        }
      }

      // Enforce role-based access for programs
      if (currentRoute.startsWith('/programs')) {
        final role = currentAuthState.selectedRole;
        if (role == 'super_admin') {
          return '/super-admin';
        }
        // Employee has no access. Allowed only for Owner, HR, Supervisor.
        if (role != 'Owner' && role != 'HR' && role != 'Supervisor') {
          return _getDashboardRoute(role);
        }
        // Add/Edit restricted to Owner only
        if (currentRoute == '/programs/add' || (currentRoute.startsWith('/programs/') && currentRoute.endsWith('/edit'))) {
          if (role != 'Owner') {
            return '/programs';
          }
        }
      }

      // Prevent super_admin from accessing regular employee workspace pages
      if (currentAuthState.selectedRole == 'super_admin') {
        if (!currentRoute.startsWith('/super-admin') && currentRoute != '/splash' && currentRoute != '/login') {
          return '/super-admin';
        }
      }

      // Enforce role-based access. Make sure logged in user stays on their allowed dashboard.
      if (currentRoute == '/owner-dashboard' && currentAuthState.selectedRole != 'Owner') {
        return _getDashboardRoute(currentAuthState.selectedRole);
      }
      if (currentRoute == '/hr-dashboard' && currentAuthState.selectedRole != 'HR' && currentAuthState.selectedRole != 'Supervisor') {
        return _getDashboardRoute(currentAuthState.selectedRole);
      }
      if (currentRoute == '/employee-dashboard' && currentAuthState.selectedRole != 'Employee') {
        return _getDashboardRoute(currentAuthState.selectedRole);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/owner-dashboard',
        name: 'owner_dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/hr-dashboard',
        name: 'hr_dashboard',
        builder: (context, state) => const HRDashboardScreen(),
      ),
      GoRoute(
        path: '/employee-dashboard',
        name: 'employee_dashboard',
        builder: (context, state) => const EmployeeDashboardScreen(),
      ),
      GoRoute(
        path: '/employees',
        name: 'employee_list',
        builder: (context, state) => const EmployeeListScreen(),
      ),
      GoRoute(
        path: '/employees/add',
        name: 'employee_add',
        builder: (context, state) => const EmployeeFormScreen(),
      ),
      GoRoute(
        path: '/employees/:id',
        name: 'employee_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EmployeeDetailScreen(employeeId: id);
        },
      ),
      GoRoute(
        path: '/employees/:id/edit',
        name: 'employee_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final employee = state.extra as EmployeeModel?;
          return EmployeeFormScreen(employeeId: id, employee: employee);
        },
      ),
      GoRoute(
        path: '/employees/:id/performance',
        name: 'employee_performance',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EmployeePerformanceScreen(employeeId: id);
        },
      ),
      GoRoute(
        path: '/machines',
        name: 'machine_list',
        builder: (context, state) => const MachineListScreen(),
      ),
      GoRoute(
        path: '/machines/add',
        name: 'machine_add',
        builder: (context, state) => const MachineFormScreen(),
      ),
      GoRoute(
        path: '/machines/detail/:id',
        name: 'machine_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MachineDetailScreen(machineId: id);
        },
      ),
      GoRoute(
        path: '/machines/edit/:id',
        name: 'machine_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final machine = state.extra as MachineModel?;
          return MachineFormScreen(machineId: id, machine: machine);
        },
      ),
      GoRoute(
        path: '/tooling',
        name: 'tool_list',
        builder: (context, state) => const ToolListScreen(),
      ),
      GoRoute(
        path: '/tooling/add',
        name: 'tool_add',
        builder: (context, state) => const ToolFormScreen(),
      ),
      GoRoute(
        path: '/tooling/:id',
        name: 'tool_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ToolDetailScreen(toolId: id);
        },
      ),
      GoRoute(
        path: '/tooling/:id/edit',
        name: 'tool_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final tool = state.extra as ToolModel?;
          return ToolFormScreen(toolId: id, tool: tool);
        },
      ),
      GoRoute(
        path: '/drawings',
        name: 'drawing_list',
        builder: (context, state) => const DrawingListScreen(),
      ),
      GoRoute(
        path: '/drawings/add',
        name: 'drawing_add',
        builder: (context, state) => const DrawingFormScreen(),
      ),
      GoRoute(
        path: '/programs',
        name: 'program_list',
        builder: (context, state) => const ProgramListScreen(),
      ),
      GoRoute(
        path: '/programs/add',
        name: 'program_add',
        builder: (context, state) => const ProgramFormScreen(),
      ),
      GoRoute(
        path: '/programs/:id/edit',
        name: 'program_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final program = state.extra as ProgramModel?;
          return ProgramFormScreen(programId: id, program: program);
        },
      ),
      GoRoute(
        path: '/attendance',
        name: 'attendance_dashboard',
        builder: (context, state) => const AttendanceDashboardScreen(),
      ),
      GoRoute(
        path: '/attendance/mark',
        name: 'attendance_mark',
        builder: (context, state) => const MarkAttendanceScreen(),
      ),
      GoRoute(
        path: '/attendance/today',
        name: 'attendance_today',
        builder: (context, state) => const TodaysAttendanceScreen(),
      ),
      GoRoute(
        path: '/attendance/history',
        name: 'attendance_history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/attendance/monthly',
        name: 'attendance_monthly',
        builder: (context, state) => const MonthlyAttendanceScreen(),
      ),
      GoRoute(
        path: '/attendance/employee/:id',
        name: 'attendance_employee_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EmployeeAttendanceDetailScreen(employeeId: id);
        },
      ),
      GoRoute(
        path: '/attendance/search',
        name: 'attendance_search',
        builder: (context, state) => const SearchAttendanceScreen(),
      ),
      GoRoute(
        path: '/tasks',
        name: 'task_dashboard',
        builder: (context, state) => const TaskDashboardScreen(),
      ),
      GoRoute(
        path: '/tasks/list',
        name: 'task_list',
        builder: (context, state) {
          final status = state.uri.queryParameters['status'];
          return TaskListScreen(initialStatus: status);
        },
      ),
      GoRoute(
        path: '/tasks/my-tasks',
        name: 'task_my_tasks',
        builder: (context, state) => const TaskMyTasksScreen(),
      ),
      GoRoute(
        path: '/tasks/completed',
        name: 'task_completed',
        builder: (context, state) => const TaskCompletedScreen(),
      ),
      GoRoute(
        path: '/tasks/create',
        name: 'task_create',
        builder: (context, state) => const TaskFormScreen(),
      ),
      GoRoute(
        path: '/tasks/:id',
        name: 'task_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TaskDetailScreen(taskId: id);
        },
      ),
      GoRoute(
        path: '/tasks/:id/edit',
        name: 'task_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final task = state.extra as TaskModel?;
          return TaskFormScreen(taskId: id, task: task);
        },
      ),
      GoRoute(
        path: '/leaves',
        name: 'leave_dashboard',
        builder: (context, state) => const LeaveDashboardScreen(),
      ),
      GoRoute(
        path: '/leaves/apply',
        name: 'leave_apply',
        builder: (context, state) => const ApplyLeaveScreen(),
      ),
      GoRoute(
        path: '/leaves/history',
        name: 'leave_history',
        builder: (context, state) => const MyLeaveHistoryScreen(),
      ),
      GoRoute(
        path: '/leaves/requests',
        name: 'leave_requests',
        builder: (context, state) {
          final status = state.uri.queryParameters['status'];
          return CompanyLeaveRequestsScreen(initialStatus: status);
        },
      ),
      GoRoute(
        path: '/leaves/approval',
        name: 'leave_approval',
        builder: (context, state) => const LeaveApprovalScreen(),
      ),
      GoRoute(
        path: '/leaves/calendar',
        name: 'leave_calendar',
        builder: (context, state) => const LeaveCalendarScreen(),
      ),
      GoRoute(
        path: '/leaves/:id',
        name: 'leave_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LeaveDetailScreen(leaveId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications_dashboard',
        builder: (context, state) => const NotificationsDashboardScreen(),
      ),
      GoRoute(
        path: '/notifications/list',
        name: 'notifications_list',
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: '/notifications/create',
        name: 'notifications_create',
        builder: (context, state) {
          final notif = state.extra as NotificationModel?;
          return CreateAnnouncementScreen(notification: notif);
        },
      ),
      GoRoute(
        path: '/notifications/history',
        name: 'notifications_history',
        builder: (context, state) => const AnnouncementHistoryScreen(),
      ),
      GoRoute(
        path: '/notifications/:id',
        name: 'notification_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return NotificationDetailScreen(notificationId: id);
        },
      ),
      GoRoute(
        path: '/inventory',
        name: 'inventory_list',
        builder: (context, state) => const InventoryListScreen(),
      ),
      GoRoute(
        path: '/inventory/add',
        name: 'inventory_add',
        builder: (context, state) => const InventoryFormScreen(),
      ),
      GoRoute(
        path: '/inventory/edit/:id',
        name: 'inventory_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InventoryFormScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/inventory/details/:id',
        name: 'inventory_details',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InventoryDetailScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/inventory/:id',
        name: 'inventory_detail_alias',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InventoryDetailScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/purchase',
        name: 'purchase_list',
        builder: (context, state) => const PurchaseListScreen(),
      ),
      GoRoute(
        path: '/purchase/add',
        name: 'purchase_add',
        builder: (context, state) => const PurchaseFormScreen(),
      ),
      GoRoute(
        path: '/purchase/edit/:id',
        name: 'purchase_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PurchaseFormScreen(purchaseId: id);
        },
      ),
      GoRoute(
        path: '/purchases/:id',
        name: 'purchase_detail_alias',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PurchaseFormScreen(purchaseId: id);
        },
      ),
      GoRoute(
        path: '/sales',
        name: 'sales_list',
        builder: (context, state) => const SalesListScreen(),
      ),
      GoRoute(
        path: '/sales/add',
        name: 'sales_add',
        builder: (context, state) => const SalesFormScreen(),
      ),
      GoRoute(
        path: '/sales/edit/:id',
        name: 'sales_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SalesFormScreen(saleId: id);
        },
      ),
      GoRoute(
        path: '/sales/:id',
        name: 'sales_detail_alias',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SalesFormScreen(saleId: id);
        },
      ),
      GoRoute(
        path: '/sales/analytics',
        name: 'sales_analytics',
        builder: (context, state) => const SalesAnalyticsScreen(),
      ),
      GoRoute(
        path: '/production',
        name: 'production_list',
        builder: (context, state) => const ProductionListScreen(),
      ),
      GoRoute(
        path: '/production/create',
        name: 'production_create',
        builder: (context, state) => const ProductionFormScreen(),
      ),
      GoRoute(
        path: '/production/:id/edit',
        name: 'production_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final prod = state.extra as ProductionModel?;
          return ProductionFormScreen(productionId: id, production: prod);
        },
      ),
      GoRoute(
        path: '/production/:id',
        name: 'production_details',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductionDetailScreen(productionId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/activity',
        name: 'activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/billing',
        name: 'billing_placeholder',
        builder: (context, state) => const BillingPlaceholderScreen(),
      ),
      GoRoute(
        path: '/comparison',
        name: 'comparison',
        builder: (context, state) => const ComparisonScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsHomeScreen(),
      ),
      GoRoute(
        path: '/super-admin',
        name: 'super_admin_dashboard',
        builder: (context, state) => const SuperAdminDashboardScreen(),
      ),
      GoRoute(
        path: '/super-admin/companies',
        name: 'super_admin_companies',
        builder: (context, state) => const SuperAdminCompanyListScreen(),
      ),
      GoRoute(
        path: '/super-admin/create-company',
        name: 'super_admin_create_company',
        builder: (context, state) => const SuperAdminCreateCompanyScreen(),
      ),
      GoRoute(
        path: '/super-admin/company/:companyId',
        name: 'super_admin_company_detail',
        builder: (context, state) {
          final id = state.pathParameters['companyId']!;
          return SuperAdminCompanyDetailScreen(companyId: id);
        },
      ),
      GoRoute(
        path: '/super-admin/company/:companyId/edit',
        name: 'super_admin_company_edit',
        builder: (context, state) {
          final id = state.pathParameters['companyId']!;
          return SuperAdminEditCompanyScreen(companyId: id);
        },
      ),
      GoRoute(
        path: '/super-admin/company/:companyId/settings',
        name: 'super_admin_company_settings',
        builder: (context, state) {
          final id = state.pathParameters['companyId']!;
          return SuperAdminCompanySettingsScreen(companyId: id);
        },
      ),
      GoRoute(
        path: '/super-admin/company/:companyId/owner',
        name: 'super_admin_company_owner',
        builder: (context, state) {
          final id = state.pathParameters['companyId']!;
          return SuperAdminOwnerDetailScreen(companyId: id);
        },
      ),
    ],
  );
});

String _getDashboardRoute(String? role) {
  if (role == 'super_admin') {
    return '/super-admin';
  } else if (role == 'Owner') {
    return '/owner-dashboard';
  } else if (role == 'HR' || role == 'Supervisor') {
    return '/hr-dashboard';
  } else {
    return '/employee-dashboard';
  }
}
