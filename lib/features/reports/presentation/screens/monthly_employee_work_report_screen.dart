import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/file_saver.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../../tasks/domain/models/task_model.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../utils/employee_work_report_pdf_generator.dart';

class MonthlyEmployeeWorkReportScreen extends ConsumerStatefulWidget {
  const MonthlyEmployeeWorkReportScreen({super.key});

  @override
  ConsumerState<MonthlyEmployeeWorkReportScreen> createState() => _MonthlyEmployeeWorkReportScreenState();
}

class _MonthlyEmployeeWorkReportScreenState extends ConsumerState<MonthlyEmployeeWorkReportScreen> {
  String? _selectedEmployeeId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final companyId = authState.user?.companyId ?? '';

    // Gate access: Owner, HR, Supervisor, Admin
    final isAuthorized = role == 'Owner' || role == 'HR' || role == 'Supervisor' || role == 'super_admin';
    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Only Owners, HR, and Supervisors can access Employee Work Reports.')),
      );
    }

    final employeesAsync = ref.watch(companyEmployeesProvider);
    final tasksAsync = ref.watch(companyTasksStreamProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Monthly Task Work Report'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading employees: $err')),
        data: (employees) {
          if (employees.isEmpty) {
            return const Center(child: Text('No employees registered in company.'));
          }

          // Default selected employee to first if not set
          final currentSelectedEmp = employees.where((e) => e.employeeId == _selectedEmployeeId).firstOrNull ?? employees.first;
          _selectedEmployeeId = currentSelectedEmp.employeeId;

          return tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading task history: $err')),
            data: (allTasks) {
              // Filter completed tasks for selected employee & selected month
              final employeeTasks = allTasks.where((t) {
                final isSameEmp = t.assignedToEmployeeId == currentSelectedEmp.employeeId ||
                    t.assignedToUid == currentSelectedEmp.uid;
                if (!isSameEmp) return false;
                if (t.status != 'Completed') return false;

                final compDate = t.actualCompletionTime ?? t.completedDate;
                if (compDate == null) return false;
                return compDate.year == _selectedMonth.year && compDate.month == _selectedMonth.month;
              }).toList();

              // Sort ascending by completion date
              employeeTasks.sort((a, b) {
                final dA = a.actualCompletionTime ?? a.completedDate ?? a.startDate;
                final dB = b.actualCompletionTime ?? b.completedDate ?? b.startDate;
                return dA.compareTo(dB);
              });

              // Group by day & compute totals
              final Map<String, List<TaskModel>> groupedByDay = {};
              final Map<String, int> dailyTotalsMinutes = {};
              int monthlyTotalMinutes = 0;

              for (final task in employeeTasks) {
                final compDate = task.actualCompletionTime ?? task.completedDate ?? task.startDate;
                final dayKey = DateFormat('yyyy-MM-dd').format(compDate);

                groupedByDay.putIfAbsent(dayKey, () => []).add(task);
                final duration = EmployeeWorkReportPdfGenerator.calculateTaskDurationMinutes(task);
                dailyTotalsMinutes[dayKey] = (dailyTotalsMinutes[dayKey] ?? 0) + duration;
                monthlyTotalMinutes += duration;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Control Panel: Employee Selector, Month Picker, Export Button
                        _buildControlPanel(
                          context,
                          theme,
                          isDark,
                          employees,
                          currentSelectedEmp,
                          companyId,
                          employeeTasks,
                          dailyTotalsMinutes,
                          monthlyTotalMinutes,
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // Summary Metric Cards
                        _buildMetricsCards(theme, isDark, employeeTasks.length, monthlyTotalMinutes),
                        const SizedBox(height: AppSizes.p24),

                        // Report Header Note
                        _buildReportNote(theme, isDark),
                        const SizedBox(height: AppSizes.p16),

                        // Report Table
                        _buildReportTable(
                          theme,
                          isDark,
                          groupedByDay,
                          dailyTotalsMinutes,
                          monthlyTotalMinutes,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<EmployeeModel> employees,
    EmployeeModel selectedEmployee,
    String companyId,
    List<TaskModel> completedTasks,
    Map<String, int> dailyTotals,
    int monthlyTotalMinutes,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: isDark ? BorderSide(color: Colors.white.withAlpha(20)) : BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Filters & Export',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Employee Dropdown
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedEmployee.employeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: employees.map((emp) {
                      return DropdownMenuItem<String>(
                        value: emp.employeeId,
                        child: Text('${emp.name} (${emp.employeeId})', style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEmployeeId = val;
                        });
                      }
                    },
                  ),
                ),

                // Month Picker Button
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedMonth,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'SELECT REPORT MONTH',
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedMonth = DateTime(picked.year, picked.month, 1);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.primaryLight),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Download PDF / Print Button
                ElevatedButton.icon(
                  onPressed: _isGeneratingPdf
                      ? null
                      : () async {
                          setState(() => _isGeneratingPdf = true);
                          try {
                            final pdfBytes = await EmployeeWorkReportPdfGenerator.generatePdf(
                              companyId: companyId,
                              employee: selectedEmployee,
                              selectedMonth: _selectedMonth,
                              tasks: completedTasks,
                            );

                            final fileName =
                                'task_work_report_${selectedEmployee.employeeId}_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf';
                            saveFile(pdfBytes, fileName, 'application/pdf');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PDF Report generated & downloaded successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to generate PDF: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isGeneratingPdf = false);
                          }
                        },
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Print / Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards(ThemeData theme, bool isDark, int taskCount, int totalMinutes) {
    final avgMinutes = taskCount > 0 ? totalMinutes ~/ taskCount : 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            theme,
            isDark,
            'Completed Tasks',
            '$taskCount',
            Icons.task_alt_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: AppSizes.p16),
        Expanded(
          child: _buildMetricCard(
            theme,
            isDark,
            'Total Task Working Time',
            EmployeeWorkReportPdfGenerator.formatMinutes(totalMinutes),
            Icons.timelapse_rounded,
            Colors.green,
          ),
        ),
        const SizedBox(width: AppSizes.p16),
        Expanded(
          child: _buildMetricCard(
            theme,
            isDark,
            'Avg Time per Task',
            EmployeeWorkReportPdfGenerator.formatMinutes(avgMinutes),
            Icons.av_timer_rounded,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    ThemeData theme,
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSizes.p16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportNote(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Task Working Hours track actual time spent working on assigned tasks (start to completion) and are strictly separate from Attendance records.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(
    ThemeData theme,
    bool isDark,
    Map<String, List<TaskModel>> groupedByDay,
    Map<String, int> dailyTotals,
    int monthlyTotalMinutes,
  ) {
    if (groupedByDay.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSizes.p32),
          child: Center(
            child: Text(
              'No completed task working history for this employee in the selected month.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Task Work Log',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groupedByDay.keys.length,
              itemBuilder: (context, idx) {
                final dayKey = groupedByDay.keys.elementAt(idx);
                final dayTasks = groupedByDay[dayKey] ?? [];
                final dailyTotalMinutes = dailyTotals[dayKey] ?? 0;
                final dateFormatted = DateFormat('dd MMMM yyyy').format(DateTime.parse(dayKey));

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSizes.p20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      // Day Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.inputRadius - 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_note_rounded, size: 18, color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                Text(
                                  dateFormatted,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Daily Total: ${EmployeeWorkReportPdfGenerator.formatMinutes(dailyTotalMinutes)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tasks Table under this day
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(1.2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50,
                              border: Border(bottom: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200)),
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.all(10), child: Text('Task Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(10), child: Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(10), child: Text('Completion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(10), child: Text('Time Spent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(10), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          ...dayTasks.map((t) {
                            final duration = EmployeeWorkReportPdfGenerator.calculateTaskDurationMinutes(t);
                            return TableRow(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade100)),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      if (t.department.isNotEmpty)
                                        Text(t.department, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    EmployeeWorkReportPdfGenerator.formatTimestamp(t.taskStartTime),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    EmployeeWorkReportPdfGenerator.formatTimestamp(t.actualCompletionTime ?? t.completedDate),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    EmployeeWorkReportPdfGenerator.formatMinutes(duration),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    t.status,
                                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: AppSizes.p16),
            const Divider(),
            const SizedBox(height: AppSizes.p8),

            // Monthly Total Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MONTHLY TOTAL TASK WORKING TIME',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  EmployeeWorkReportPdfGenerator.formatMinutes(monthlyTotalMinutes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
