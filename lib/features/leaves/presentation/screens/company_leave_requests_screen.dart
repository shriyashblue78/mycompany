import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../domain/models/leave_model.dart';
import '../providers/leaves_provider.dart';

class CompanyLeaveRequestsScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const CompanyLeaveRequestsScreen({super.key, this.initialStatus});

  @override
  ConsumerState<CompanyLeaveRequestsScreen> createState() => _CompanyLeaveRequestsScreenState();
}

class _CompanyLeaveRequestsScreenState extends ConsumerState<CompanyLeaveRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialStatus != null) {
        ref.read(leaveStatusFilterProvider.notifier).state = widget.initialStatus;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leavesAsync = ref.watch(filteredLeavesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isManager = role == 'Owner' || role == 'HR';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Staff Leave Requests'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: Column(
        children: [
          // Filters Panel
          _buildFiltersPanel(context, isManager),

          // Requests Results list
          Expanded(
            child: leavesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading requests: $err')),
              data: (leaves) {
                if (leaves.isEmpty) {
                  return _buildEmptyState(context);
                }

                // Sort leaves by applied date descending
                final sorted = leaves..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

                return _buildResponsiveList(context, sorted, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context, bool isManager) {
    final theme = Theme.of(context);

    final searchQuery = ref.watch(leaveSearchQueryProvider);
    final selectedDept = ref.watch(leaveDepartmentFilterProvider);
    final selectedType = ref.watch(leaveTypeFilterProvider);
    final selectedStatus = ref.watch(leaveStatusFilterProvider);
    final startDate = ref.watch(leaveStartDateFilterProvider);
    final endDate = ref.watch(leaveEndDateFilterProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      color: theme.colorScheme.surface,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            children: [
              // Search field
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search requests by employee name or reason...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            ref.read(leaveSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) {
                  ref.read(leaveSearchQueryProvider.notifier).state = val;
                },
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: searchQuery,
                    selection: TextSelection.collapsed(offset: searchQuery.length),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),

              // Dropdown selectors Wrap
              Wrap(
                spacing: AppSizes.p8,
                runSpacing: AppSizes.p8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Department Dropdown (Only visible for managers; supervisors are bound to their dept)
                  if (isManager)
                    _buildDropdown(
                      label: 'Department',
                      value: selectedDept,
                      items: ['All', ...kDepartments],
                      onChanged: (val) {
                        ref.read(leaveDepartmentFilterProvider.notifier).state = val == 'All' ? null : val;
                      },
                    ),

                  // Leave Type Dropdown
                  _buildDropdown(
                    label: 'Leave Type',
                    value: selectedType,
                    items: ['All', ...kLeaveTypes],
                    onChanged: (val) {
                      ref.read(leaveTypeFilterProvider.notifier).state = val == 'All' ? null : val;
                    },
                  ),

                  // Status Dropdown
                  _buildDropdown(
                    label: 'Status',
                    value: selectedStatus,
                    items: ['All', ...kLeaveStatuses],
                    onChanged: (val) {
                      ref.read(leaveStatusFilterProvider.notifier).state = val == 'All' ? null : val;
                    },
                  ),

                  // Date range filters
                  TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        helpText: 'Select Start Date Filter Boundary',
                      );
                      if (date != null) {
                        ref.read(leaveStartDateFilterProvider.notifier).state = date;
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      startDate != null
                          ? 'From: ${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'
                          : 'From Date',
                    ),
                  ),

                  TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime(2020),
                        lastDate: DateTime(2030),
                        helpText: 'Select End Date Filter Boundary',
                      );
                      if (date != null) {
                        ref.read(leaveEndDateFilterProvider.notifier).state = date;
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      endDate != null
                          ? 'To: ${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}'
                          : 'To Date',
                    ),
                  ),

                  // Reset Filters
                  if (searchQuery.isNotEmpty ||
                      selectedDept != null ||
                      selectedType != null ||
                      selectedStatus != null ||
                      startDate != null ||
                      endDate != null)
                    TextButton(
                      onPressed: () {
                        ref.read(leaveSearchQueryProvider.notifier).state = '';
                        ref.read(leaveDepartmentFilterProvider.notifier).state = null;
                        ref.read(leaveTypeFilterProvider.notifier).state = null;
                        ref.read(leaveStatusFilterProvider.notifier).state = null;
                        ref.read(leaveStartDateFilterProvider.notifier).state = null;
                        ref.read(leaveEndDateFilterProvider.notifier).state = null;
                      },
                      child: const Text('Reset', style: TextStyle(color: AppColors.error)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? 'All',
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text('$label: $item', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No Requests Found',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            const Text(
              'Try relaxing your search query or filter parameters to display other records.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveList(
    BuildContext context,
    List<LeaveModel> list,
    bool isDark,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        padding: const EdgeInsets.all(AppSizes.p16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSizes.p16,
            mainAxisSpacing: AppSizes.p16,
            mainAxisExtent: 180,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final leave = list[index];
            return _buildLeaveCard(context, leave, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeaveModel leave, bool isDark) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(leave.status);

    final startStr = '${leave.startDate.year}-${leave.startDate.month.toString().padLeft(2, '0')}-${leave.startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${leave.endDate.year}-${leave.endDate.month.toString().padLeft(2, '0')}-${leave.endDate.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? theme.colorScheme.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: isDark ? BorderSide(color: Colors.white.withAlpha(15), width: 1) : BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: InkWell(
          onTap: () => context.push('/leaves/${leave.leaveId}'),
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Employee Name
                    Expanded(
                      child: Text(
                        leave.employeeName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Status tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        leave.status,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Dept: ${leave.department}  |  Type: ${leave.leaveType}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const Spacer(),

                // Leave days and dates
                Text(
                  '${leave.totalDays} Days Requested',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$startStr to $endStr',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Reason summary
                Text(
                  leave.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return AppColors.success;
      case 'Rejected':
        return AppColors.error;
      case 'Cancelled':
        return Colors.grey.shade600;
      default:
        return AppColors.warning;
    }
  }
}
