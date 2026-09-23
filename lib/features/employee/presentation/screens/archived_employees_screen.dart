import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/employee_model.dart';
import '../providers/employee_provider.dart';

class ArchivedEmployeesScreen extends ConsumerStatefulWidget {
  const ArchivedEmployeesScreen({super.key});

  @override
  ConsumerState<ArchivedEmployeesScreen> createState() => _ArchivedEmployeesScreenState();
}

class _ArchivedEmployeesScreenState extends ConsumerState<ArchivedEmployeesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRestoring = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isOwner = role == 'Owner' || role == 'super_admin';

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only Company Owners can view archived employee records.'),
        ),
      );
    }

    final archivedAsync = ref.watch(archivedEmployeesProvider);
    final countAsync = ref.watch(activeEmployeesCountProvider);
    final companyAsync = ref.watch(currentCompanyStreamProvider);
    final company = companyAsync.value;
    final maxEmployees = company?.maxEmployees ?? 50;
    final currentCount = countAsync.value ?? 0;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Archived Workforce History'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Banner
                  _buildHeaderBanner(theme, isDark, currentCount, maxEmployees),
                  const SizedBox(height: AppSizes.p20),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search archived workforce by name, ID, or department...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim().toLowerCase());
                    },
                  ),
                  const SizedBox(height: AppSizes.p20),

                  // List of Archived Employees
                  archivedAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error loading archived workforce: $err')),
                    data: (employees) {
                      final filtered = employees.where((emp) {
                        if (_searchQuery.isEmpty) return true;
                        return emp.name.toLowerCase().contains(_searchQuery) ||
                            emp.employeeId.toLowerCase().contains(_searchQuery) ||
                            emp.department.toLowerCase().contains(_searchQuery) ||
                            emp.email.toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return _buildEmptyState(theme, isDark);
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final emp = filtered[idx];
                          return _buildArchivedTile(context, theme, isDark, emp, currentCount, maxEmployees);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(ThemeData theme, bool isDark, int activeCount, int maxEmployees) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.archive_rounded, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: AppSizes.p16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archived Workforce Records',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Removed employees are archived for audit and historical task/attendance reports. Active seats available: ${maxEmployees - activeCount} / $maxEmployees.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSizes.p32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No Archived Employees Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('All employee records in your workforce are currently active.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedTile(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    EmployeeModel emp,
    int activeCount,
    int maxEmployees,
  ) {
    final removedDateStr = emp.deletedAt != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(emp.deletedAt!)
        : 'N/A';
    final joinedDateStr = DateFormat('dd MMM yyyy').format(emp.joiningDate);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Status Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withAlpha(30),
                  backgroundImage: emp.photoUrl != null && emp.photoUrl!.isNotEmpty
                      ? NetworkImage(emp.photoUrl!)
                      : null,
                  child: emp.photoUrl == null || emp.photoUrl!.isEmpty
                      ? Text(emp.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            emp.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              emp.employeeId,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${emp.designation} • ${emp.department} (${emp.role})',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Archived / Inactive',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Middle Info Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Joined Date:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(joinedDateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Removed On:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(removedDateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Removed By:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(emp.deletedByName ?? 'Owner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            if (emp.deletionReason != null && emp.deletionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Removal Reason: ${emp.deletionReason}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 16),
            // Bottom Action Bar: Restore Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isRestoring
                    ? null
                    : () => _confirmAndRestore(context, emp, activeCount, maxEmployees),
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('Restore to Active Workforce'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndRestore(
    BuildContext context,
    EmployeeModel emp,
    int activeCount,
    int maxEmployees,
  ) {
    if (activeCount >= maxEmployees) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Employee Limit Reached'),
            ],
          ),
          content: Text(
            'Cannot restore ${emp.name}.\nYour company is currently at its maximum employee seat capacity ($activeCount/$maxEmployees).\n\nPlease upgrade your seat limit or remove an active employee before restoring.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Employee?'),
        content: Text(
          'Are you sure you want to restore ${emp.name} (${emp.employeeId}) back to the active workforce?\n\nThis will re-enable login access and consume 1 employee seat ($activeCount/$maxEmployees occupied).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isRestoring = true);
              try {
                final authState = ref.read(authProvider);
                final companyId = authState.user?.companyId ?? '';

                await ref.read(employeeRepositoryProvider).restoreEmployee(
                      companyId: companyId,
                      employeeId: emp.employeeId,
                    );

                ref.invalidate(archivedEmployeesProvider);
                ref.invalidate(filteredEmployeesProvider);
                ref.invalidate(activeEmployeesCountProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${emp.name} has been restored to active workforce!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to restore employee: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isRestoring = false);
              }
            },
            child: const Text('Restore Employee'),
          ),
        ],
      ),
    );
  }
}
