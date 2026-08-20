import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/employee_model.dart';
import '../providers/employee_provider.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
  });

  @override
  ConsumerState<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  bool _isActionLoading = false;

  Future<void> _toggleStatus(EmployeeModel employee) async {
    final repository = ref.read(employeeRepositoryProvider);
    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;

    if (companyId == null) return;

    final isActivating = employee.status != 'Active';
    final actionName = isActivating ? 'Activate' : 'Deactivate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveDialog(
        child: AlertDialog(
          title: Text('$actionName Employee?'),
          content: Text('Are you sure you want to $actionName ${employee.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: isActivating ? AppColors.success : AppColors.error,
              ),
              child: Text(actionName),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isActionLoading = true;
    });

    try {
      final newStatus = isActivating ? 'Active' : 'Inactive';
      await repository.updateEmployeeStatus(
        companyId: companyId,
        employeeId: employee.employeeId,
        status: newStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee successfully ${isActivating ? "activated" : "deactivated"}.'),
            backgroundColor: isActivating ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeAsync = ref.watch(employeeStreamProvider(widget.employeeId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          employeeAsync.when(
            data: (employee) {
              if (employee == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit Profile',
                onPressed: () {
                  context.push('/employees/${employee.employeeId}/edit', extra: employee);
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: employeeAsync.when(
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
                Text('Failed to load employee details', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSizes.p8),
                Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: AppSizes.p16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(employeeStreamProvider(widget.employeeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (employee) {
          if (employee == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: AppSizes.p16),
                  Text('Employee Not Found', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSizes.p8),
                  const Text('This employee record does not exist or has been deleted.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: AppSizes.p16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return ResponsiveLayout(
            mobile: _buildMobileLayout(context, employee, isDark),
            tablet: _buildTabletLayout(context, employee, isDark),
            desktop: _buildTabletLayout(context, employee, isDark),
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, EmployeeModel employee, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        children: [
          _buildHeaderSection(context, employee, isDark),
          const SizedBox(height: AppSizes.p20),
          _buildDetailsGrid(context, employee, isDark),
          const SizedBox(height: AppSizes.p24),
          _buildActionsSection(context, employee),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, EmployeeModel employee, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildHeaderSection(context, employee, isDark),
                    const SizedBox(height: AppSizes.p20),
                    _buildActionsSection(context, employee),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.p24),
              Expanded(
                flex: 6,
                child: _buildDetailsGrid(context, employee, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, EmployeeModel employee, bool isDark) {
    final theme = Theme.of(context);
    final isActive = employee.status == 'Active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade100,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _buildAvatar(employee, 110),
          const SizedBox(height: AppSizes.p16),
          Text(
            employee.name,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.p4),
          Text(
            '${employee.designation} • ${employee.department}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.p12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.success : AppColors.error).withAlpha(30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              employee.status,
              style: TextStyle(
                color: isActive ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
          border: Border.all(color: AppColors.primaryLight, width: 3),
          image: DecorationImage(
            image: NetworkImage(employee.photoUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final initials = employee.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryLight, width: 3),
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'E',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(BuildContext context, EmployeeModel employee, bool isDark) {
    final theme = Theme.of(context);

    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('MMMM dd, yyyy hh:mm a');

    final details = [
      _DetailItem('Employee ID', employee.employeeId, Icons.badge_outlined),
      _DetailItem('Email Address', employee.email, Icons.email_outlined),
      _DetailItem('Phone Number', employee.phone, Icons.phone_outlined),
      _DetailItem('Department', employee.department, Icons.corporate_fare_rounded),
      _DetailItem('Designation', employee.designation, Icons.work_outline_rounded),
      _DetailItem('System Role', employee.role, Icons.security_rounded),
      _DetailItem('Joining Date', dateFormat.format(employee.joiningDate), Icons.calendar_today_outlined),
      _DetailItem(
        'Last Login',
        employee.lastLogin != null ? timeFormat.format(employee.lastLogin!) : 'Never',
        Icons.login_rounded,
      ),
      _DetailItem('Account Created', dateFormat.format(employee.createdAt), Icons.add_circle_outline_rounded),
      _DetailItem('Last Updated', dateFormat.format(employee.updatedAt), Icons.update_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade100,
          width: 1.5,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: details.length,
        separatorBuilder: (context, index) => Divider(
          color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200,
          height: AppSizes.p24,
        ),
        itemBuilder: (context, index) {
          final item = details[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: AppSizes.p16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, EmployeeModel employee) {
    final isActive = employee.status == 'Active';

    return Column(
      children: [
        CustomButton(
          text: 'Edit Profile',
          icon: Icons.edit_rounded,
          onPressed: () {
            context.push('/employees/${employee.employeeId}/edit', extra: employee);
          },
        ),
        const SizedBox(height: AppSizes.p12),
        CustomButton(
          text: 'View Performance History',
          icon: Icons.assessment_rounded,
          onPressed: () {
            context.push('/employees/${employee.employeeId}/performance');
          },
        ),
        const SizedBox(height: AppSizes.p12),
        CustomButton(
          text: isActive ? 'Deactivate Employee' : 'Activate Employee',
          icon: isActive ? Icons.block_rounded : Icons.check_circle_rounded,
          isLoading: _isActionLoading,
          onPressed: () => _toggleStatus(employee),
        ),
      ],
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;

  _DetailItem(this.label, this.value, this.icon);
}
