import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/leave_model.dart';
import '../providers/leaves_provider.dart';

class MyLeaveHistoryScreen extends ConsumerWidget {
  const MyLeaveHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(companyLeavesStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('My Leave History'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: leavesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading leave history: $err')),
        data: (leaves) {
          // Filter to show ONLY current employee's leaves
          final myLeaves = leaves.where((l) => l.employeeId == user.employeeId).toList()
            ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

          if (myLeaves.isEmpty) {
            return _buildEmptyState(context);
          }

          final isMobile = ResponsiveLayout.isMobile(context);
          final isTablet = ResponsiveLayout.isTablet(context);
          final columns = isMobile ? 1 : (isTablet ? 2 : 3);

          if (isMobile) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: myLeaves.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final leave = myLeaves[i];
                final dateRange = '${DateFormat('MMM d').format(leave.startDate)} - ${DateFormat('MMM d, y').format(leave.endDate)}';
                return MobileListTile(
                  title: leave.leaveType,
                  subtitle: dateRange,
                  meta: '${leave.totalDays} day(s) · ${leave.reason}',
                  leadingIcon: Icons.time_to_leave_rounded,
                  leadingColor: Colors.orange,
                  statusLabel: leave.status,
                  onTap: () => context.push('/leaves/detail/${leave.leaveId}'),
                );
              },
            );
          }

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              padding: const EdgeInsets.all(AppSizes.p24),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSizes.p16,
                  mainAxisSpacing: AppSizes.p16,
                  mainAxisExtent: 220,
                ),
                itemCount: myLeaves.length,
                itemBuilder: (context, index) {
                  final leave = myLeaves[index];
                  return _buildLeaveHistoryTile(context, ref, theme, leave, isDark);
                },
              ),
            ),
          );
        },
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
              Icons.history_toggle_off_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No Leave History',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              'You have not submitted any leave requests yet.\nUse the button below to apply for leaves.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSizes.p24),
            ElevatedButton.icon(
              onPressed: () => context.push('/leaves/apply'),
              icon: const Icon(Icons.add_moderator_rounded),
              label: const Text('Apply For Leave'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveHistoryTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    LeaveModel leave,
    bool isDark,
  ) {
    final statusColor = _getStatusColor(leave.status);
    final startStr = '${leave.startDate.year}-${leave.startDate.month.toString().padLeft(2, '0')}-${leave.startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${leave.endDate.year}-${leave.endDate.month.toString().padLeft(2, '0')}-${leave.endDate.day.toString().padLeft(2, '0')}';
    final isPending = leave.status == 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
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
            padding: const EdgeInsets.all(AppSizes.p20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Leave Type title
                    Expanded(
                      child: Text(
                        leave.leaveType,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Status Badge
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
                const SizedBox(height: AppSizes.p8),

                // Date ranges & Total Days
                Text(
                  'Range: $startStr  to  $endStr  (${leave.totalDays} Days)',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),

                // Reason summary
                Text(
                  leave.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                ),

                if (isPending) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmCancelRequest(context, ref, leave),
                        icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                        label: const Text('Cancel Request', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmCancelRequest(BuildContext context, WidgetRef ref, LeaveModel leave) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Leave Request?'),
          content: const Text('Are you sure you want to cancel this pending leave request? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final updated = leave.copyWith(status: 'Cancelled');
                  await ref.read(leaveRepositoryProvider).updateLeave(leave.companyId, updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Leave request successfully cancelled.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel request: $e')),
                  );
                }
              },
              child: const Text('Yes, Cancel Request', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
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
