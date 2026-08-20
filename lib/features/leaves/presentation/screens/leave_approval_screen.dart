import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../domain/models/leave_model.dart';
import '../providers/leaves_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class LeaveApprovalScreen extends ConsumerWidget {
  const LeaveApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(companyLeavesStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    final role = user.role;
    final isSupervisor = role == 'Supervisor';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Pending Leave Approvals'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: leavesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSizes.p24),
          child: CardListSkeleton(),
        ),
        error: (err, stack) => Center(child: Text('Error loading approvals: $err')),
        data: (leaves) {
          // Filter to show ONLY Pending requests (restricted to supervisor's department if supervisor)
          final pendingLeaves = leaves.where((l) {
            final isPending = l.status == 'Pending';
            if (isSupervisor) {
              return isPending && l.department == user.department;
            }
            return isPending;
          }).toList();

          if (pendingLeaves.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.check_circle_outline_rounded,
              title: 'No Pending Approvals',
              description: 'All caught up! There are no pending leave requests awaiting your approval.',
            );
          }

            final isMobile = ResponsiveLayout.isMobile(context);
            final isTablet = ResponsiveLayout.isTablet(context);
            final columns = isMobile ? 1 : (isTablet ? 2 : 3);

            if (isMobile) {
              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: ListView.builder(
                    itemCount: pendingLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = pendingLeaves[index];
                      return _buildPendingTile(context, theme, leave, isDark);
                    },
                  ),
                ),
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
                    mainAxisExtent: 180,
                  ),
                  itemCount: pendingLeaves.length,
                  itemBuilder: (context, index) {
                    final leave = pendingLeaves[index];
                    return _buildPendingTile(context, theme, leave, isDark);
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
              Icons.check_circle_outline_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No Pending Approvals',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            const Text(
              'All catch up! There are no pending leave requests awaiting your approval.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTile(BuildContext context, ThemeData theme, LeaveModel leave, bool isDark) {
    final startStr = '${leave.startDate.year}-${leave.startDate.month.toString().padLeft(2, '0')}-${leave.startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${leave.endDate.year}-${leave.endDate.month.toString().padLeft(2, '0')}-${leave.endDate.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? theme.colorScheme.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: AppColors.warning.withAlpha(isDark ? 80 : 40), width: 1.5),
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
                    // Employee Name
                    Text(
                      leave.employeeName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Action tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Needs Review',
                        style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Dept: ${leave.department}  |  Leave Type: ${leave.leaveType}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const Divider(height: 24),

                // Details Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${leave.totalDays} Days: $startStr to $endStr',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reason: ${leave.reason}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
