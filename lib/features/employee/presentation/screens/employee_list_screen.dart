import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../domain/models/employee_model.dart';
import '../providers/employee_provider.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(filteredEmployeesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listeners for filters
    final searchQuery = ref.watch(employeeSearchQueryProvider);
    final selectedDept = ref.watch(employeeDepartmentFilterProvider);
    final selectedRole = ref.watch(employeeRoleFilterProvider);
    final selectedStatus = ref.watch(employeeStatusFilterProvider);
    final limit = ref.watch(employeeLimitProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Employee Directory'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(filteredEmployeesProvider);
            },
          ),
        ],
      ),
      drawer: const ERPDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employees/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Employee'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Filter Panel
            _buildSearchFilterPanel(context, ref, isDark),
            
            // Employee List / Grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredEmployeesProvider);
                },
                child: employeesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                          const SizedBox(height: AppSizes.p16),
                          Text('Failed to load employee list', style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSizes.p8),
                          Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const SizedBox(height: AppSizes.p16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(filteredEmployeesProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (employees) {
                    if (employees.isEmpty) {
                      return _buildEmptyState(context, ref, searchQuery, selectedDept, selectedRole, selectedStatus);
                    }
                    return _buildResponsiveList(context, ref, employees, limit);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterPanel(BuildContext context, WidgetRef ref, bool isDark) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            children: [
              // Search Text Field
              TextField(
                onChanged: (val) => ref.read(employeeSearchQueryProvider.notifier).state = val,
                decoration: InputDecoration(
                  hintText: 'Search by Name, ID, Email, or Phone...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: ref.watch(employeeSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            ref.read(employeeSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              
              // Responsive Dropdowns
              if (isMobile)
                ExpansionTile(
                  title: const Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
                  leading: const Icon(Icons.filter_list_rounded),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
                      child: Column(
                        children: [
                          _buildDeptDropdown(context, ref),
                          const SizedBox(height: AppSizes.p8),
                          _buildRoleDropdown(context, ref),
                          const SizedBox(height: AppSizes.p8),
                          _buildStatusDropdown(context, ref),
                          const SizedBox(height: AppSizes.p8),
                          _buildClearFiltersButton(ref),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _buildDeptDropdown(context, ref)),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(child: _buildRoleDropdown(context, ref)),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(child: _buildStatusDropdown(context, ref)),
                    const SizedBox(width: AppSizes.p12),
                    _buildClearFiltersButton(ref),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeptDropdown(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(employeeDepartmentFilterProvider);
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Department',
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Departments')),
        ...kDepartments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
      ],
      onChanged: (val) {
        ref.read(employeeDepartmentFilterProvider.notifier).state = val;
      },
    );
  }

  Widget _buildRoleDropdown(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(employeeRoleFilterProvider);
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Role',
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Roles')),
        ...kRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))),
      ],
      onChanged: (val) {
        ref.read(employeeRoleFilterProvider.notifier).state = val;
      },
    );
  }

  Widget _buildStatusDropdown(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(employeeStatusFilterProvider);
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Status',
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Statuses')),
        ...kStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      ],
      onChanged: (val) {
        ref.read(employeeStatusFilterProvider.notifier).state = val;
      },
    );
  }

  Widget _buildClearFiltersButton(WidgetRef ref) {
    final hasActiveFilters = ref.watch(employeeDepartmentFilterProvider) != null ||
        ref.watch(employeeRoleFilterProvider) != null ||
        ref.watch(employeeStatusFilterProvider) != null;

    if (!hasActiveFilters) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () {
        ref.read(employeeDepartmentFilterProvider.notifier).state = null;
        ref.read(employeeRoleFilterProvider.notifier).state = null;
        ref.read(employeeStatusFilterProvider.notifier).state = null;
      },
      icon: const Icon(Icons.clear_all_rounded, color: AppColors.error),
      label: const Text('Clear', style: TextStyle(color: AppColors.error)),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    String query,
    String? dept,
    String? role,
    String? status,
  ) {
    final theme = Theme.of(context);
    final hasFilters = query.isNotEmpty || dept != null || role != null || status != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              hasFilters ? 'No Matching Employees' : 'No Employees Registered',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              hasFilters
                  ? 'Try relaxing your search terms or filter configurations.'
                  : 'Add a new employee to start building your workforce directory.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSizes.p24),
            if (hasFilters)
              ElevatedButton(
                onPressed: () {
                  ref.read(employeeSearchQueryProvider.notifier).state = '';
                  ref.read(employeeDepartmentFilterProvider.notifier).state = null;
                  ref.read(employeeRoleFilterProvider.notifier).state = null;
                  ref.read(employeeStatusFilterProvider.notifier).state = null;
                },
                child: const Text('Reset All Filters'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.push('/employees/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Employee'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveList(
    BuildContext context,
    WidgetRef ref,
    List<EmployeeModel> employees,
    int currentLimit,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
        itemCount: employees.length + (employees.length >= currentLimit ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == employees.length) {
            return Center(
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(employeeLimitProvider.notifier).state = currentLimit + 15,
                icon: const Icon(Icons.arrow_downward_rounded),
                label: Text('Load More (${employees.length} shown)'),
              ),
            );
          }
          final emp = employees[i];
          final isActive = emp.status == 'Active';
          return MobileListTile(
            title: emp.name,
            subtitle: '${emp.role} · ${emp.department}',
            meta: emp.email,
            leading: CircleAvatar(
              radius: 22,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
              backgroundImage:
                  emp.photoUrl != null ? NetworkImage(emp.photoUrl!) : null,
              child: emp.photoUrl == null
                  ? Text(
                      emp.name.isNotEmpty
                          ? emp.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            statusLabel: emp.status,
            statusColor: isActive ? AppColors.success : Colors.grey,
            onTap: () => context.push('/employees/${emp.employeeId}'),
          );
        },
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.p16),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSizes.p16,
                mainAxisSpacing: AppSizes.p16,
                mainAxisExtent: 130,
              ),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final employee = employees[index];
                return _buildEmployeeCard(context, employee);
              },
            ),
            if (employees.length >= currentLimit)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.p24),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      ref.read(employeeLimitProvider.notifier).state = currentLimit + 15;
                    },
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: Text('Load More (Showing ${employees.length})'),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(BuildContext context, EmployeeModel employee) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = employee.status == 'Active';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/employees/${employee.employeeId}'),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Row(
            children: [
              // Photo / Avatar
              _buildAvatar(employee, 56),
              const SizedBox(width: AppSizes.p16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            employee.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildStatusBadge(isActive),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${employee.employeeId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${employee.designation} • ${employee.department}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(179),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${employee.role}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(employee.role, theme),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(EmployeeModel employee, double size) {
    if (employee.photoUrl != null && employee.photoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(employee.photoUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Default Initials-based Avatar
    final initials = employee.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'E',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(String role, ThemeData theme) {
    switch (role) {
      case 'Owner':
        return Colors.purple;
      case 'HR':
        return AppColors.accentLight;
      case 'Supervisor':
        return theme.colorScheme.primary;
      default:
        return Colors.blueGrey;
    }
  }
}
