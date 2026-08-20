import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../../attendance/domain/models/attendance_model.dart';
import '../../../attendance/presentation/providers/attendance_provider.dart';
import '../../../inventory/domain/models/inventory_item_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../production/domain/models/production_model.dart';
import '../../../production/presentation/providers/production_provider.dart';
import '../../../purchase/domain/models/purchase_model.dart';
import '../../../purchase/presentation/providers/purchase_provider.dart';
import '../../../sales/domain/models/sale_model.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../../leaves/domain/models/leave_model.dart';
import '../../../leaves/presentation/providers/leaves_provider.dart';
import '../../../tasks/domain/models/task_model.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';

// Helper class for Recent Activity feed items
class ActivityItem {
  final String title;
  final DateTime dateTime;
  final IconData icon;
  final Color color;
  final String description;
  final String moduleType; // 'Attendance', 'Production', 'Purchase', 'Sales', 'Leave', 'Tasks', 'Inventory'

  const ActivityItem({
    required this.title,
    required this.dateTime,
    required this.icon,
    required this.color,
    this.description = '',
    this.moduleType = '',
  });
}

// Helper class containing all compiled Smart Dashboard statistics
class DashboardStatsData {
  final int totalEmployees;
  final int presentToday;
  final int lowStockItems;
  final int runningProduction;
  final double todayPurchasesAmount;
  final int todayPurchasesCount;
  final double todaySalesAmount;
  final int todaySalesCount;
  final int pendingLeaveRequests;
  final int pendingTasks;
  final List<ActivityItem> recentActivities;

  const DashboardStatsData({
    required this.totalEmployees,
    required this.presentToday,
    required this.lowStockItems,
    required this.runningProduction,
    required this.todayPurchasesAmount,
    required this.todayPurchasesCount,
    required this.todaySalesAmount,
    required this.todaySalesCount,
    required this.pendingLeaveRequests,
    required this.pendingTasks,
    required this.recentActivities,
  });
}

// Main Provider compiling all metrics dynamically from existing collection streams
final smartDashboardProvider = Provider<AsyncValue<DashboardStatsData>>((ref) {
  final employeesAsync = ref.watch(allActiveEmployeesProvider);
  final attendanceAsync = ref.watch(companyAttendanceStreamProvider);
  final inventoryAsync = ref.watch(companyInventoryStreamProvider);
  final productionAsync = ref.watch(companyProductionsStreamProvider);
  final purchaseAsync = ref.watch(companyPurchasesStreamProvider);
  final salesAsync = ref.watch(companySalesStreamProvider);
  final leavesAsync = ref.watch(companyLeavesStreamProvider);
  final tasksAsync = ref.watch(companyTasksStreamProvider);

  // Check loading state of all required collections
  if (employeesAsync.isLoading ||
      attendanceAsync.isLoading ||
      inventoryAsync.isLoading ||
      productionAsync.isLoading ||
      purchaseAsync.isLoading ||
      salesAsync.isLoading ||
      leavesAsync.isLoading ||
      tasksAsync.isLoading) {
    return const AsyncValue.loading();
  }

  // Handle errors
  if (employeesAsync.hasError) return AsyncValue.error(employeesAsync.error!, employeesAsync.stackTrace!);
  if (attendanceAsync.hasError) return AsyncValue.error(attendanceAsync.error!, attendanceAsync.stackTrace!);
  if (inventoryAsync.hasError) return AsyncValue.error(inventoryAsync.error!, inventoryAsync.stackTrace!);
  if (productionAsync.hasError) return AsyncValue.error(productionAsync.error!, productionAsync.stackTrace!);
  if (purchaseAsync.hasError) return AsyncValue.error(purchaseAsync.error!, purchaseAsync.stackTrace!);
  if (salesAsync.hasError) return AsyncValue.error(salesAsync.error!, salesAsync.stackTrace!);
  if (leavesAsync.hasError) return AsyncValue.error(leavesAsync.error!, leavesAsync.stackTrace!);
  if (tasksAsync.hasError) return AsyncValue.error(tasksAsync.error!, tasksAsync.stackTrace!);

  final employees = employeesAsync.value ?? [];
  final attendance = attendanceAsync.value ?? [];
  final inventory = inventoryAsync.value ?? [];
  final production = productionAsync.value ?? [];
  final purchases = purchaseAsync.value ?? [];
  final sales = salesAsync.value ?? [];
  final leaves = leavesAsync.value ?? [];
  final tasks = tasksAsync.value ?? [];

  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  // 1. Total Employees (active status)
  final activeEmployees = employees.where((e) => e.status == 'Active').toList();
  final totalEmployeesCount = activeEmployees.length;

  // 2. Present Today count
  final todayRecords = attendance.where((rec) {
    final dateStr = '${rec.date.year}-${rec.date.month.toString().padLeft(2, '0')}-${rec.date.day.toString().padLeft(2, '0')}';
    return dateStr == todayStr;
  }).toList();

  int presentTodayCount = 0;
  for (final emp in activeEmployees) {
    final hasRecord = todayRecords.any((rec) {
      if (rec.employeeId == emp.employeeId) {
        final status = rec.status.toLowerCase();
        return status == 'present' || status == 'late' || status == 'half day';
      }
      return false;
    });
    if (hasRecord) {
      presentTodayCount++;
    }
  }

  // 3. Low Stock Items (removed minimumStock, default to <= 0 stock check)
  final lowStockCount = inventory.where((item) => item.currentStock <= 0).length;

  // 4. Running Production count (In Progress status)
  final runningProdCount = production.where((prod) => prod.status == 'In Progress').length;

  // 5. Today's Purchases sum
  double todayPurchAmount = 0.0;
  final todayPurchs = purchases.where((p) {
    return p.purchaseDate.year == now.year &&
        p.purchaseDate.month == now.month &&
        p.purchaseDate.day == now.day &&
        p.status != 'Cancelled';
  }).toList();
  for (final p in todayPurchs) {
    todayPurchAmount += p.totalAmount;
  }

  // 6. Today's Sales sum
  double todaySalesAmount = 0.0;
  final todaySls = sales.where((s) {
    return s.saleDate.year == now.year &&
        s.saleDate.month == now.month &&
        s.saleDate.day == now.day &&
        s.status != 'Cancelled';
  }).toList();
  for (final s in todaySls) {
    todaySalesAmount += s.totalAmount;
  }

  // 7. Pending Leaves count
  final pendingLeavesCount = leaves.where((l) => l.status == 'Pending').length;

  // 8. Pending Tasks count
  final pendingTasksCount = tasks.where((t) => t.status == 'Pending').length;

  // COMPUTE RECENT ACTIVITY LIST (Latest 5 items)
  final allActs = compileActivities(
    employees: employees,
    attendance: attendance,
    inventory: inventory,
    production: production,
    purchases: purchases,
    sales: sales,
    leaves: leaves,
    tasks: tasks,
  );
  final latestActivities = allActs.take(5).toList();

  return AsyncValue.data(DashboardStatsData(
    totalEmployees: totalEmployeesCount,
    presentToday: presentTodayCount,
    lowStockItems: lowStockCount,
    runningProduction: runningProdCount,
    todayPurchasesAmount: todayPurchAmount,
    todayPurchasesCount: todayPurchs.length,
    todaySalesAmount: todaySalesAmount,
    todaySalesCount: todaySls.length,
    pendingLeaveRequests: pendingLeavesCount,
    pendingTasks: pendingTasksCount,
    recentActivities: latestActivities,
  ));
});

// Helper function to compile and format activities from all database collections
List<ActivityItem> compileActivities({
  required List<EmployeeModel> employees,
  required List<AttendanceModel> attendance,
  required List<InventoryItemModel> inventory,
  required List<ProductionModel> production,
  required List<PurchaseModel> purchases,
  required List<SaleModel> sales,
  required List<LeaveModel> leaves,
  required List<TaskModel> tasks,
}) {
  final List<ActivityItem> activities = [];

  // Attendance
  for (final rec in attendance) {
    final emp = employees.firstWhere(
      (e) => e.employeeId == rec.employeeId,
      orElse: () => EmployeeModel(
        employeeId: rec.employeeId, uid: '', companyId: '',
        name: 'Employee', email: '', phone: '', role: '',
        department: '', designation: '', status: '', joiningDate: DateTime.now(),
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    );
    if (rec.attendanceId.isNotEmpty && rec.status.toLowerCase() != 'absent') {
      activities.add(ActivityItem(
        title: '${emp.name} marked attendance',
        dateTime: rec.updatedAt,
        icon: Icons.fingerprint_rounded,
        color: Colors.green,
        description: 'Status: ${rec.status}. Check-in time: ${rec.checkInTime ?? 'N/A'}.',
        moduleType: 'Attendance',
      ));
    }
  }

  // Purchases
  for (final p in purchases) {
    activities.add(ActivityItem(
      title: 'Purchase Order ${p.purchaseNumber}',
      dateTime: p.createdAt,
      icon: Icons.shopping_cart_rounded,
      color: Colors.blue,
      description: 'Purchase record created for supplier: ${p.supplierName}. Status: ${p.status}. Total Amount: \$${p.totalAmount.toStringAsFixed(2)}.',
      moduleType: 'Purchase',
    ));
  }

  // Productions
  for (final prod in production) {
    activities.add(ActivityItem(
      title: 'Production - ${prod.productName}',
      dateTime: prod.updatedAt,
      icon: Icons.precision_manufacturing_rounded,
      color: Colors.purple,
      description: 'Production record updated. Status: ${prod.status}. Batch quantity: ${prod.quantity}. Completed: ${prod.completedQuantity}.',
      moduleType: 'Production',
    ));
  }

  // Sales
  for (final s in sales) {
    activities.add(ActivityItem(
      title: 'Sale Order ${s.saleNumber}',
      dateTime: s.updatedAt,
      icon: Icons.sell_rounded,
      color: Colors.teal,
      description: 'Sale record updated for customer: ${s.customerName}. Status: ${s.status}. Total Amount: \$${s.totalAmount.toStringAsFixed(2)}.',
      moduleType: 'Sales',
    ));
  }

  // Leaves
  for (final l in leaves) {
    activities.add(ActivityItem(
      title: 'Leave request: ${l.employeeName}',
      dateTime: l.updatedAt,
      icon: Icons.time_to_leave_rounded,
      color: Colors.orange,
      description: '${l.leaveType} request. Reason: ${l.reason}. Status: ${l.status}. Date range: ${l.startDate.day}/${l.startDate.month} to ${l.endDate.day}/${l.endDate.month}.',
      moduleType: 'Leave',
    ));
  }

  // Tasks
  for (final t in tasks) {
    final emp = employees.firstWhere(
      (e) => e.employeeId == t.assignedToEmployeeId,
      orElse: () => EmployeeModel(
        employeeId: t.assignedToEmployeeId, uid: '', companyId: '',
        name: 'Unassigned', email: '', phone: '', role: '',
        department: '', designation: '', status: '', joiningDate: DateTime.now(),
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    );
    activities.add(ActivityItem(
      title: 'Task: ${t.title}',
      dateTime: t.updatedAt,
      icon: Icons.task_rounded,
      color: Colors.indigo,
      description: 'Task updated. Status: ${t.status}. Assigned to: ${emp.name}. Priority: ${t.priority}.',
      moduleType: 'Tasks',
    ));
  }

  // Inventory
  for (final item in inventory) {
    if (item.currentStock <= 0) {
      activities.add(ActivityItem(
        title: 'Out of stock alert for ${item.itemName}',
        dateTime: item.updatedAt,
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
        description: 'Current Stock: 0 ${item.unit}. Part Number: ${item.partNumber}.',
        moduleType: 'Inventory',
      ));
    } else {
      activities.add(ActivityItem(
        title: 'Inventory Item: ${item.itemName}',
        dateTime: item.updatedAt,
        icon: Icons.inventory_2_rounded,
        color: Colors.redAccent,
        description: 'Inventory item updated. Current Stock: ${item.currentStock} ${item.unit}. Part Number: ${item.partNumber}.',
        moduleType: 'Inventory',
      ));
    }
  }

  // Sort newest first
  activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return activities;
}

// Global Provider compiling all activities dynamically from existing streams
final companyActivitiesProvider = Provider<AsyncValue<List<ActivityItem>>>((ref) {
  final employeesAsync = ref.watch(allActiveEmployeesProvider);
  final attendanceAsync = ref.watch(companyAttendanceStreamProvider);
  final inventoryAsync = ref.watch(companyInventoryStreamProvider);
  final productionAsync = ref.watch(companyProductionsStreamProvider);
  final purchaseAsync = ref.watch(companyPurchasesStreamProvider);
  final salesAsync = ref.watch(companySalesStreamProvider);
  final leavesAsync = ref.watch(companyLeavesStreamProvider);
  final tasksAsync = ref.watch(companyTasksStreamProvider);

  if (employeesAsync.isLoading ||
      attendanceAsync.isLoading ||
      inventoryAsync.isLoading ||
      productionAsync.isLoading ||
      purchaseAsync.isLoading ||
      salesAsync.isLoading ||
      leavesAsync.isLoading ||
      tasksAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (employeesAsync.hasError) return AsyncValue.error(employeesAsync.error!, employeesAsync.stackTrace!);
  if (attendanceAsync.hasError) return AsyncValue.error(attendanceAsync.error!, attendanceAsync.stackTrace!);
  if (inventoryAsync.hasError) return AsyncValue.error(inventoryAsync.error!, inventoryAsync.stackTrace!);
  if (productionAsync.hasError) return AsyncValue.error(productionAsync.error!, productionAsync.stackTrace!);
  if (purchaseAsync.hasError) return AsyncValue.error(purchaseAsync.error!, purchaseAsync.stackTrace!);
  if (salesAsync.hasError) return AsyncValue.error(salesAsync.error!, salesAsync.stackTrace!);
  if (leavesAsync.hasError) return AsyncValue.error(leavesAsync.error!, leavesAsync.stackTrace!);
  if (tasksAsync.hasError) return AsyncValue.error(tasksAsync.error!, tasksAsync.stackTrace!);

  final employees = employeesAsync.value ?? [];
  final attendance = attendanceAsync.value ?? [];
  final inventory = inventoryAsync.value ?? [];
  final production = productionAsync.value ?? [];
  final purchases = purchaseAsync.value ?? [];
  final sales = salesAsync.value ?? [];
  final leaves = leavesAsync.value ?? [];
  final tasks = tasksAsync.value ?? [];

  final allActs = compileActivities(
    employees: employees,
    attendance: attendance,
    inventory: inventory,
    production: production,
    purchases: purchases,
    sales: sales,
    leaves: leaves,
    tasks: tasks,
  );

  return AsyncValue.data(allActs);
});
