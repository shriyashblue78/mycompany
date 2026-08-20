import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/utils/file_saver.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../attendance/presentation/providers/attendance_provider.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../production/presentation/providers/production_provider.dart';
import '../../../purchase/presentation/providers/purchase_provider.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../leaves/presentation/providers/leaves_provider.dart';

import '../../../attendance/domain/models/attendance_model.dart';
import '../../../inventory/domain/models/inventory_item_model.dart';
import '../../../production/domain/models/production_model.dart';
import '../../../purchase/domain/models/purchase_model.dart';
import '../../../sales/domain/models/sale_model.dart';
import '../../../tasks/domain/models/task_model.dart';
import '../../../leaves/domain/models/leave_model.dart';

class ReportsHomeScreen extends ConsumerStatefulWidget {
  const ReportsHomeScreen({super.key});

  @override
  ConsumerState<ReportsHomeScreen> createState() => _ReportsHomeScreenState();
}

class _ReportsHomeScreenState extends ConsumerState<ReportsHomeScreen> {
  DateTimeRange? _selectedDateRange;
  
  // Date range picker helper
  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // Check if a date falls within range
  bool _isWithinRange(DateTime date, DateTime start, DateTime end) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, cleanDay(end).day);
    return (cleanDate.isAfter(cleanStart) || cleanDate.isAtSameMomentAs(cleanStart)) &&
        (cleanDate.isBefore(cleanEnd) || cleanDate.isAtSameMomentAs(cleanEnd));
  }

  DateTime cleanDay(DateTime dt) {
    return dt.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Auth context
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    
    // Safety redirection if supervisor or employee enters somehow
    if (role != 'Owner' && role != 'HR') {
      return const Scaffold(
        body: Center(
          child: Text('Access Denied. Owner or HR permissions required.'),
        ),
      );
    }

    // Watch all data streams
    final employeesAsync = ref.watch(allActiveEmployeesProvider);
    final attendanceAsync = ref.watch(companyAttendanceStreamProvider);
    final inventoryAsync = ref.watch(companyInventoryStreamProvider);
    final productionsAsync = ref.watch(companyProductionsStreamProvider);
    final purchasesAsync = ref.watch(companyPurchasesStreamProvider);
    final salesAsync = ref.watch(companySalesStreamProvider);
    final tasksAsync = ref.watch(companyTasksStreamProvider);
    final leavesAsync = ref.watch(companyLeavesStreamProvider);

    // Show loading state if any stream is active
    if (employeesAsync is AsyncLoading ||
        attendanceAsync is AsyncLoading ||
        inventoryAsync is AsyncLoading ||
        productionsAsync is AsyncLoading ||
        purchasesAsync is AsyncLoading ||
        salesAsync is AsyncLoading ||
        tasksAsync is AsyncLoading ||
        leavesAsync is AsyncLoading) {
      return const Scaffold(
        drawer: ERPDrawer(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Get loaded data
    final employees = employeesAsync.value ?? [];
    final attendance = attendanceAsync.value ?? [];
    final inventory = inventoryAsync.value ?? [];
    final productions = productionsAsync.value ?? [];
    final purchases = purchasesAsync.value ?? [];
    final sales = salesAsync.value ?? [];
    final tasks = tasksAsync.value ?? [];
    final leaves = leavesAsync.value ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(now.year, now.month, 1);

    // Apply custom date range if selected
    final startRange = _selectedDateRange?.start ?? today;
    final endRange = _selectedDateRange?.end ?? now;

    // Filters for Today, Month, Total
    bool isToday(DateTime dt) => dt.year == now.year && dt.month == now.month && dt.day == now.day;
    bool isThisMonth(DateTime dt) => dt.year == now.year && dt.month == now.month;

    // Calculate metrics
    // Attendance
    final attendanceToday = attendance.where((a) => isToday(a.date)).toList();
    final attendanceMonth = attendance.where((a) => isThisMonth(a.date)).toList();
    
    int presentToday = attendanceToday.where((a) => a.status == 'Present').length;
    int absentToday = attendanceToday.where((a) => a.status == 'Absent').length;
    int lateToday = attendanceToday.where((a) => a.status == 'Late').length;

    int presentMonth = attendanceMonth.where((a) => a.status == 'Present').length;
    int absentMonth = attendanceMonth.where((a) => a.status == 'Absent').length;
    int lateMonth = attendanceMonth.where((a) => a.status == 'Late').length;

    int presentTotal = attendance.where((a) => a.status == 'Present').length;
    int absentTotal = attendance.where((a) => a.status == 'Absent').length;
    int lateTotal = attendance.where((a) => a.status == 'Late').length;

    // Inventory
    int totalItems = inventory.length;
    int lowStockItems = 0;
    int outOfStockItems = inventory.where((i) => i.currentStock <= 0).length;

    // Production
    final prodToday = productions.where((p) => isToday(p.productionDate)).toList();
    final prodMonth = productions.where((p) => isThisMonth(p.productionDate)).toList();

    int runningToday = prodToday.where((p) => p.status == 'Running').length;
    int completedToday = prodToday.where((p) => p.status == 'Completed').length;
    int cancelledToday = prodToday.where((p) => p.status == 'Cancelled').length;

    int runningMonth = prodMonth.where((p) => p.status == 'Running').length;
    int completedMonth = prodMonth.where((p) => p.status == 'Completed').length;
    int cancelledMonth = prodMonth.where((p) => p.status == 'Cancelled').length;

    int runningTotal = productions.where((p) => p.status == 'Running').length;
    int completedTotal = productions.where((p) => p.status == 'Completed').length;
    int cancelledTotal = productions.where((p) => p.status == 'Cancelled').length;

    // Purchase
    final purchaseToday = purchases.where((p) => isToday(p.purchaseDate)).toList();
    final purchaseMonth = purchases.where((p) => isThisMonth(p.purchaseDate)).toList();

    double purchaseAmountToday = purchaseToday.fold(0.0, (sum, p) => sum + p.totalAmount);
    double purchaseAmountMonth = purchaseMonth.fold(0.0, (sum, p) => sum + p.totalAmount);
    double purchaseAmountTotal = purchases.fold(0.0, (sum, p) => sum + p.totalAmount);

    // Sales
    final salesToday = sales.where((s) => isToday(s.saleDate)).toList();
    final salesMonth = sales.where((s) => isThisMonth(s.saleDate)).toList();

    double salesAmountToday = salesToday.fold(0.0, (sum, s) => sum + s.totalAmount);
    double salesAmountMonth = salesMonth.fold(0.0, (sum, s) => sum + s.totalAmount);
    double salesAmountTotal = sales.fold(0.0, (sum, s) => sum + s.totalAmount);

    // Pending Leaves & Tasks
    int pendingLeavesCount = leaves.where((l) => l.status == 'Pending').length;
    int pendingTasksCount = tasks.where((t) => t.status == 'Pending').length;

    // Prepare chart data for line chart (Sales Trend of This Month)
    List<FlSpot> salesSpots = [];
    final salesByDay = <int, double>{};
    for (var s in salesMonth) {
      salesByDay[s.saleDate.day] = (salesByDay[s.saleDate.day] ?? 0.0) + s.totalAmount;
    }
    for (int d = 1; d <= now.day; d++) {
      salesSpots.add(FlSpot(d.toDouble(), salesByDay[d] ?? 0.0));
    }

    // Helper: export CSV file
    void exportCSV() {
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('ERP REPORTS AND ANALYTICS');
      csvBuffer.writeln('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
      csvBuffer.writeln();
      
      csvBuffer.writeln('SUMMARY');
      csvBuffer.writeln('Metric,Count');
      csvBuffer.writeln('Total Employees,${employees.length}');
      csvBuffer.writeln('Present Today,$presentToday');
      csvBuffer.writeln('Absent Today,$absentToday');
      csvBuffer.writeln('Total Inventory Items,$totalItems');
      csvBuffer.writeln('Low Stock Items,$lowStockItems');
      csvBuffer.writeln('Running Productions,$runningTotal');
      csvBuffer.writeln('Today\'s Purchases,${purchaseToday.length} ($purchaseAmountToday)');
      csvBuffer.writeln('Today\'s Sales,${salesToday.length} ($salesAmountToday)');
      csvBuffer.writeln('Pending Leaves,$pendingLeavesCount');
      csvBuffer.writeln('Pending Tasks,$pendingTasksCount');
      csvBuffer.writeln();

      csvBuffer.writeln('DETAILED METRICS TABLE');
      csvBuffer.writeln('Section,Metric,Today,This Month,Total');
      csvBuffer.writeln('Attendance,Present,$presentToday,$presentMonth,$presentTotal');
      csvBuffer.writeln('Attendance,Absent,$absentToday,$absentMonth,$absentTotal');
      csvBuffer.writeln('Attendance,Late,$lateToday,$lateMonth,$lateTotal');
      csvBuffer.writeln('Inventory,Total Items,$totalItems,$totalItems,$totalItems');
      csvBuffer.writeln('Inventory,Low Stock,$lowStockItems,$lowStockItems,$lowStockItems');
      csvBuffer.writeln('Inventory,Out Of Stock,$outOfStockItems,$outOfStockItems,$outOfStockItems');
      csvBuffer.writeln('Production,Running,$runningToday,$runningMonth,$runningTotal');
      csvBuffer.writeln('Production,Completed,$completedToday,$completedMonth,$completedTotal');
      csvBuffer.writeln('Production,Cancelled,$cancelledToday,$cancelledMonth,$cancelledTotal');
      csvBuffer.writeln('Purchase,Amount,$purchaseAmountToday,$purchaseAmountMonth,$purchaseAmountTotal');
      csvBuffer.writeln('Sales,Amount,$salesAmountToday,$salesAmountMonth,$salesAmountTotal');

      final bytes = utf8.encode(csvBuffer.toString());
      saveFile(bytes, 'erp_report_${DateFormat('yyyyMMdd').format(now)}.csv', 'text/csv');
    }

    // Helper: export PDF file
    Future<void> exportPDF() async {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('Manufacturing ERP - Reports & Analytics Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                ),
                pw.Text('Report Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
                pw.SizedBox(height: 16),
                
                pw.Text('General Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>['KPI Metric', 'Value'],
                    <String>['Total Employees', '${employees.length}'],
                    <String>['Present Today', '$presentToday'],
                    <String>['Absent Today', '$absentToday'],
                    <String>['Total Inventory Items', '$totalItems'],
                    <String>['Low Stock Items', '$lowStockItems'],
                    <String>['Running Productions', '$runningTotal'],
                    <String>['Pending Tasks', '$pendingTasksCount'],
                    <String>['Pending Leaves', '$pendingLeavesCount'],
                  ],
                ),
                pw.SizedBox(height: 20),

                pw.Text('Detailed Reports Matrix', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>['Section', 'Metric', 'Today', 'This Month', 'Total'],
                    <String>['Attendance', 'Present', '$presentToday', '$presentMonth', '$presentTotal'],
                    <String>['Attendance', 'Absent', '$absentToday', '$absentMonth', '$absentTotal'],
                    <String>['Attendance', 'Late', '$lateToday', '$lateMonth', '$lateTotal'],
                    <String>['Inventory', 'Total Items', '$totalItems', '$totalItems', '$totalItems'],
                    <String>['Inventory', 'Low Stock', '$lowStockItems', '$lowStockItems', '$lowStockItems'],
                    <String>['Inventory', 'Out Of Stock', '$outOfStockItems', '$outOfStockItems', '$outOfStockItems'],
                    <String>['Production', 'Running', '$runningToday', '$runningMonth', '$runningTotal'],
                    <String>['Production', 'Completed', '$completedToday', '$completedMonth', '$completedTotal'],
                    <String>['Production', 'Cancelled', '$cancelledToday', '$cancelledMonth', '$cancelledTotal'],
                    <String>['Purchase', 'Total Cost', '\$$purchaseAmountToday', '\$$purchaseAmountMonth', '\$$purchaseAmountTotal'],
                    <String>['Sales', 'Total Sales', '\$$salesAmountToday', '\$$salesAmountMonth', '\$$salesAmountTotal'],
                  ],
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      saveFile(bytes, 'erp_report_${DateFormat('yyyyMMdd').format(now)}.pdf', 'application/pdf');
    }

    return ResponsiveScaffold(
      drawer: const ERPDrawer(),
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectCustomDateRange(context),
            tooltip: 'Filter Range',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (val) {
              if (val == 'csv') {
                exportCSV();
              } else if (val == 'pdf') {
                exportPDF();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'csv', child: Text('Export to CSV')),
              const PopupMenuItem(value: 'pdf', child: Text('Export to PDF')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDateRange != null) ...[
              Card(
                margin: const EdgeInsets.only(bottom: AppSizes.p16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_alt, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Date Range: ${DateFormat('yyyy-MM-dd').format(startRange)} to ${DateFormat('yyyy-MM-dd').format(endRange)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selectedDateRange = null),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Summary Cards section
            ResponsiveGrid(
              mobileCrossAxisCount: 2,
              tabletCrossAxisCount: 2,
              desktopCrossAxisCount: 4,
              mainAxisExtent: 96,
              children: [
                _buildSummaryCard('Total Employees', '${employees.length}', Icons.people, Colors.blue),
                _buildSummaryCard('Low Stock', '$lowStockItems', Icons.inventory_2, Colors.amber),
                _buildSummaryCard('Running Productions', '$runningTotal', Icons.precision_manufacturing, Colors.green),
                _buildSummaryCard('Today\'s Sales', '\$$salesAmountToday', Icons.sell, Colors.teal),
              ],
            ),

            const SizedBox(height: AppSizes.p16),

            // Small Line Chart for Sales Trend (This Month)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales Trend (This Month)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: salesSpots.isEmpty ? [const FlSpot(0, 0)] : salesSpots,
                              isCurved: true,
                              barWidth: 3,
                              color: theme.colorScheme.primary,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.p16),

            // Simple report table for Today, This Month, Total
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reports Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('Section')),
                          DataColumn(label: Text('Metric')),
                          DataColumn(label: Text('Today')),
                          DataColumn(label: Text('Month')),
                          DataColumn(label: Text('Total')),
                        ],
                        rows: [
                          _buildDataRow('Attendance', 'Present', '$presentToday', '$presentMonth', '$presentTotal'),
                          _buildDataRow('Attendance', 'Absent', '$absentToday', '$absentMonth', '$absentTotal'),
                          _buildDataRow('Attendance', 'Late', '$lateToday', '$lateMonth', '$lateTotal'),
                          _buildDataRow('Inventory', 'Total Items', '$totalItems', '$totalItems', '$totalItems'),
                          _buildDataRow('Inventory', 'Low Stock', '$lowStockItems', '$lowStockItems', '$lowStockItems'),
                          _buildDataRow('Inventory', 'Out of Stock', '$outOfStockItems', '$outOfStockItems', '$outOfStockItems'),
                          _buildDataRow('Production', 'Running', '$runningToday', '$runningMonth', '$runningTotal'),
                          _buildDataRow('Production', 'Completed', '$completedToday', '$completedMonth', '$completedTotal'),
                          _buildDataRow('Production', 'Cancelled', '$cancelledToday', '$cancelledMonth', '$cancelledTotal'),
                          _buildDataRow('Purchase', 'Amount', '\$$purchaseAmountToday', '\$$purchaseAmountMonth', '\$$purchaseAmountTotal'),
                          _buildDataRow('Sales', 'Amount', '\$$salesAmountToday', '\$$salesAmountMonth', '\$$salesAmountTotal'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(String section, String metric, String today, String month, String total) {
    return DataRow(
      cells: [
        DataCell(Text(section, style: const TextStyle(fontSize: 12))),
        DataCell(Text(metric, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        DataCell(Text(today, style: const TextStyle(fontSize: 12))),
        DataCell(Text(month, style: const TextStyle(fontSize: 12))),
        DataCell(Text(total, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
