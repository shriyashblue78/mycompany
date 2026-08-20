import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../tasks/domain/models/task_model.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';

class ComparisonGroup {
  final String title;
  final String machineName;
  final String toolsStr;
  final List<TaskModel> tasks;

  ComparisonGroup({
    required this.title,
    required this.machineName,
    required this.toolsStr,
    required this.tasks,
  });
}

class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({super.key});

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  String _searchQuery = '';
  String? _selectedMachine = 'All';
  bool _showOnlyCompleted = true;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  String _buildGroupKey(TaskModel task) {
    final List<String> tools = [];
    if (task.selectedToolNames != null) {
      tools.addAll(task.selectedToolNames!);
      tools.sort();
    }
    final job = task.title.trim().toLowerCase();
    final mach = (task.machineName ?? '').trim().toLowerCase();
    final tls = tools.join(',').trim().toLowerCase();
    return '$job|||$mach|||$tls';
  }

  List<ComparisonGroup> _groupAndFilterTasks(List<TaskModel> tasks) {
    // 1. Filter completed tasks (or all tasks based on completed toggle)
    final filteredTasks = tasks.where((t) {
      if (_showOnlyCompleted && t.status.toLowerCase() != 'completed') {
        return false;
      }
      
      // Filter by Employee Name
      if (_searchQuery.isNotEmpty) {
        final name = (t.assignedToName ?? '').toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Filter by Machine
      if (_selectedMachine != null && _selectedMachine != 'All') {
        if (t.machineName != _selectedMachine) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. Group the filtered tasks by Job + Machine + Tooling
    final Map<String, List<TaskModel>> groupsMap = {};
    for (final task in filteredTasks) {
      final key = _buildGroupKey(task);
      groupsMap.putIfAbsent(key, () => []).add(task);
    }

    // Convert map to ComparisonGroup objects
    final List<ComparisonGroup> groups = [];
    groupsMap.forEach((key, list) {
      final first = list.first;
      final tools = first.selectedToolNames != null && first.selectedToolNames!.isNotEmpty
          ? first.selectedToolNames!.join(', ')
          : '—';
      groups.add(ComparisonGroup(
        title: first.title,
        machineName: first.machineName ?? '—',
        toolsStr: tools,
        tasks: list,
      ));
    });

    // 3. Sort the groups
    if (_sortColumnIndex != null) {
      groups.sort((a, b) {
        int cmp = 0;
        switch (_sortColumnIndex) {
          case 0: // Employee Name (sort by first employee's name in group)
            final nameA = a.tasks.isNotEmpty ? (a.tasks.first.assignedToName ?? '') : '';
            final nameB = b.tasks.isNotEmpty ? (b.tasks.first.assignedToName ?? '') : '';
            cmp = nameA.compareTo(nameB);
            break;
          case 1: // Machine Name
            cmp = a.machineName.compareTo(b.machineName);
            break;
          case 3: // Job / Task Title
            cmp = a.title.compareTo(b.title);
            break;
          case 4: // Time Taken (sort by minimum time taken in the group)
            final timeA = a.tasks.map((t) => t.totalTimeTakenMinutes ?? 999999).reduce((x, y) => x < y ? x : y);
            final timeB = b.tasks.map((t) => t.totalTimeTakenMinutes ?? 999999).reduce((x, y) => x < y ? x : y);
            cmp = timeA.compareTo(timeB);
            break;
          case 5: // Performance Score (sort by maximum performance score in the group)
            final scoreA = a.tasks.map((t) => t.performanceScore ?? -1).reduce((x, y) => x > y ? x : y);
            final scoreB = b.tasks.map((t) => t.performanceScore ?? -1).reduce((x, y) => x > y ? x : y);
            cmp = scoreA.compareTo(scoreB);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(companyTasksStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Performance Comparison'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading tasks: $err')),
          data: (tasks) {
            // Get unique machines list dynamically from tasks for dropdown selection
            final uniqueMachines = tasks
                .map((t) => t.machineName)
                .where((m) => m != null && m.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();

            final processedGroups = _groupAndFilterTasks(tasks);

            return Padding(
              padding: const EdgeInsets.all(AppSizes.p16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Section Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p16),
                      child: Column(
                        children: [
                          ResponsiveFormRow(
                            children: [
                              // Search input: Employee name
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Search Employee',
                                  hintText: 'e.g. John Doe',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val.trim();
                                  });
                                },
                              ),
                              // Dropdown: Machine filter
                              DropdownButtonFormField<String>(
                                value: _selectedMachine,
                                decoration: InputDecoration(
                                  labelText: 'Filter Machine',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(value: 'All', child: Text('All Machines')),
                                  ...uniqueMachines.map((mch) {
                                    return DropdownMenuItem(value: mch, child: Text(mch));
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedMachine = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p12),
                          // Switch: Completed Only
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Display only completed jobs with performance stats',
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: AppSizes.p12),
                              Switch(
                                value: _showOnlyCompleted,
                                onChanged: (val) {
                                  setState(() {
                                    _showOnlyCompleted = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p20),

                  // Comparison Table/Card Section
                  Expanded(
                    child: processedGroups.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.compare_arrows_rounded,
                            title: 'No Matching Logs Found',
                            description: 'Ensure you have task history matching the filter selection.',
                          )
                        : isMobile
                            ? ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                itemCount: processedGroups.length,
                                itemBuilder: (context, index) {
                                  final group = processedGroups[index];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: AppSizes.p16),
                                    elevation: 2,
                                    shadowColor: theme.shadowColor.withAlpha(20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isDark ? AppColors.borderDark : Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSizes.p20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Group Header: Task/Job name
                                          Text(
                                            'Job/Task: ${group.title}',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Shared Machine & Tooling info
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'MACHINE',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(group.machineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'TOOLING',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(group.toolsStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          
                                          // Employee comparisons list
                                          const Text(
                                            'EMPLOYEE METRICS COMPARISON',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                                          ),
                                          const SizedBox(height: 8),
                                          ...group.tasks.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final t = entry.value;
                                            final isLast = idx == group.tasks.length - 1;

                                            final timeStr = t.totalTimeTakenMinutes != null
                                                ? '${t.totalTimeTakenMinutes} mins'
                                                : '—';
                                            final scoreStr = t.performanceScore != null
                                                ? '${t.performanceScore}'
                                                : '—';

                                            Color scoreColor = Colors.grey;
                                            if (t.performanceScore != null) {
                                              if (t.performanceScore! >= 85) {
                                                scoreColor = Colors.green;
                                              } else if (t.performanceScore! >= 60) {
                                                scoreColor = Colors.orange;
                                              } else {
                                                scoreColor = Colors.red;
                                              }
                                            }

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              t.assignedToName ?? 'Unassigned',
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              'Time Taken: $timeStr',
                                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: scoreColor.withAlpha(26),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: scoreColor.withAlpha(120), width: 1),
                                                        ),
                                                        child: Text(
                                                          t.performanceScore != null ? '$scoreStr Score' : 'No Score',
                                                          style: TextStyle(
                                                            color: scoreColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (!isLast) const Divider(height: 8, thickness: 0.5),
                                              ],
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: theme.dividerColor.withAlpha(50)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        sortColumnIndex: _sortColumnIndex,
                                        sortAscending: _sortAscending,
                                        columns: [
                                          const DataColumn(
                                            label: Text('Job/Task'),
                                          ),
                                          DataColumn(
                                            label: const Text('Machine'),
                                            onSort: _onSort,
                                          ),
                                          const DataColumn(
                                            label: Text('Tooling'),
                                          ),
                                          DataColumn(
                                            label: const Text('Employee'),
                                            onSort: _onSort,
                                          ),
                                          DataColumn(
                                            label: const Text('Time Taken'),
                                            numeric: true,
                                            onSort: _onSort,
                                          ),
                                          DataColumn(
                                            label: const Text('Performance Score'),
                                            numeric: true,
                                            onSort: _onSort,
                                          ),
                                        ],
                                        rows: processedGroups.expand((group) {
                                          return group.tasks.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final t = entry.value;
                                            final isFirst = idx == 0;
                                            
                                            final timeStr = t.totalTimeTakenMinutes != null
                                                ? '${t.totalTimeTakenMinutes} mins'
                                                : '—';
                                            
                                            final scoreStr = t.performanceScore != null
                                                ? '${t.performanceScore}'
                                                : '—';

                                            Color? scoreBgColor;
                                            Color? scoreTextColor;
                                            if (t.performanceScore != null) {
                                              if (t.performanceScore! >= 85) {
                                                scoreBgColor = Colors.green.withAlpha(30);
                                                scoreTextColor = Colors.green;
                                              } else if (t.performanceScore! >= 60) {
                                                scoreBgColor = Colors.orange.withAlpha(30);
                                                scoreTextColor = Colors.orange;
                                              } else {
                                                scoreBgColor = Colors.red.withAlpha(30);
                                                scoreTextColor = Colors.red;
                                              }
                                            }

                                            return DataRow(
                                              cells: [
                                                DataCell(Text(isFirst ? group.title : '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                                DataCell(Text(isFirst ? group.machineName : '')),
                                                DataCell(Text(isFirst ? group.toolsStr : '')),
                                                DataCell(Text(t.assignedToName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500))),
                                                DataCell(Text(timeStr)),
                                                DataCell(
                                                  t.performanceScore == null
                                                      ? const Text('—')
                                                      : Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: scoreBgColor,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            scoreStr,
                                                            style: TextStyle(
                                                              color: scoreTextColor,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ],
                                            );
                                          });
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
