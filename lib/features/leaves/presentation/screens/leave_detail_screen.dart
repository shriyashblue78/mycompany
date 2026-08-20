import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/leave_model.dart';
import '../providers/leaves_provider.dart';

class LeaveDetailScreen extends ConsumerStatefulWidget {
  final String leaveId;
  const LeaveDetailScreen({super.key, required this.leaveId});

  @override
  ConsumerState<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends ConsumerState<LeaveDetailScreen> {
  final _remarksController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    final leaveAsync = ref.watch(leaveDetailsStreamProvider(widget.leaveId));
    final theme = Theme.of(context);
    final role = user.role;
    final isEmployee = role == 'Employee';
    final isSupervisor = role == 'Supervisor';
    final isManager = role == 'Owner' || role == 'HR';

    return leaveAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Details...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (leave) {
        if (leave == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Request Not Found')),
            body: const Center(child: Text('The requested leave request does not exist.')),
          );
        }

        final isMobile = ResponsiveLayout.isMobile(context);
        final bodyContent = isMobile
            ? _buildMobileLayout(theme, leave, isEmployee, isSupervisor, isManager, user)
            : _buildDesktopLayout(theme, leave, isEmployee, isSupervisor, isManager, user);

        return ResponsiveScaffold(
          appBar: AppBar(
            title: Text('${leave.employeeName} - Request Details'),
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          ),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: _submitting
                    ? const Center(child: CircularProgressIndicator())
                    : bodyContent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(
    ThemeData theme,
    LeaveModel leave,
    bool isEmployee,
    bool isSupervisor,
    bool isManager,
    dynamic currentUser,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoPanel(theme, leave),
          const SizedBox(height: AppSizes.p24),
          _buildActionPanel(theme, leave, isEmployee, isSupervisor, isManager, currentUser),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    ThemeData theme,
    LeaveModel leave,
    bool isEmployee,
    bool isSupervisor,
    bool isManager,
    dynamic currentUser,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: _buildInfoPanel(theme, leave),
            ),
          ),
          const SizedBox(width: AppSizes.p24),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: _buildActionPanel(theme, leave, isEmployee, isSupervisor, isManager, currentUser),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeData theme, LeaveModel leave) {
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(leave.status);

    final startStr = '${leave.startDate.year}-${leave.startDate.month.toString().padLeft(2, '0')}-${leave.startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${leave.endDate.year}-${leave.endDate.month.toString().padLeft(2, '0')}-${leave.endDate.day.toString().padLeft(2, '0')}';
    final appliedStr = leave.appliedAt.toString().substring(0, 16);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: isDark ? BorderSide(color: Colors.white.withAlpha(20), width: 1) : BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Status: ${leave.status}',
                    style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Applied: $appliedStr',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.p20),

            // Key info items
            _buildDetailRow('Employee Name', leave.employeeName, Icons.person_rounded),
            _buildDetailRow('Department', leave.department, Icons.corporate_fare_rounded),
            _buildDetailRow('Leave Type', leave.leaveType, Icons.time_to_leave_rounded),
            _buildDetailRow('Start Date', startStr, Icons.play_arrow_outlined),
            _buildDetailRow('End Date', endStr, Icons.stop_rounded),
            _buildDetailRow('Total Days Requested', '${leave.totalDays} Days', Icons.playlist_add_check_rounded),
            const Divider(height: AppSizes.p32),

            // Reason
            Text(
              'Reason for Request',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              leave.reason,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: AppSizes.p24),

            // Supporting Document Attachment Link
            if (leave.supportingDocumentUrl != null) ...[
              const Divider(height: AppSizes.p16),
              Text(
                'Supporting Document Attachment',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSizes.p8),
              OutlinedButton.icon(
                onPressed: () {
                  // Open attachment URL (or print/preview mock logic)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening Attachment: ${leave.supportingDocumentUrl}'),
                      action: SnackBarAction(label: 'Copy URL', onPressed: () {}),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                label: const Text('View / Download Attached Slip'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary.withAlpha(180)),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(
    ThemeData theme,
    LeaveModel leave,
    bool isEmployee,
    bool isSupervisor,
    bool isManager,
    dynamic currentUser,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final isPending = leave.status == 'Pending';
    final hasRemarks = leave.approvalRemarks != null && leave.approvalRemarks!.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: isDark ? BorderSide(color: Colors.white.withAlpha(20), width: 1) : BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions & Activity',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p16),

            // Display review details if already processed
            if (!isPending) ...[
              _buildProcessedDetailRow('Processed By', leave.approvedByName ?? 'N/A'),
              if (leave.approvedAt != null)
                _buildProcessedDetailRow('Processed On', leave.approvedAt!.toString().substring(0, 16)),
              if (hasRemarks)
                _buildProcessedDetailRow('Manager Remarks', leave.approvalRemarks!),
              const SizedBox(height: 12),
              const Text(
                'This leave request has been processed and is locked from modification.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],

            // Action inputs for supervisors/managers
            if (isPending && (isSupervisor || isManager)) ...[
              const Text(
                'Enter approval or rejection remarks below to submit review decision:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter review remarks...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _processLeave(leave, 'Rejected', currentUser),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _processLeave(leave, 'Approved', currentUser),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],

            // Action for Employees to cancel
            if (isPending && isEmployee) ...[
              const Text(
                'You can cancel this leave request as it is currently pending review.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _employeeCancelLeave(leave),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],

            // Cancel action for Owners/HR on Approved requests
            if (!isPending && leave.status == 'Approved' && isManager) ...[
              const Divider(height: 24),
              const Text(
                'As Owner/HR, you can override and Cancel this approved leave.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _processLeave(leave, 'Cancelled', currentUser),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Cancel Approved Leave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessedDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const Divider(height: 16),
        ],
      ),
    );
  }

  void _processLeave(LeaveModel leave, String targetStatus, dynamic manager) async {
    final remarks = _remarksController.text.trim();
    if (targetStatus == 'Rejected' && remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remarks are required to reject leave requests.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final updated = leave.copyWith(
        status: targetStatus,
        approvedByUid: manager.uid,
        approvedByName: manager.name ?? 'Manager',
        approvalRemarks: remarks.isNotEmpty ? remarks : 'No remarks entered.',
        approvedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(leaveRepositoryProvider).updateLeave(leave.companyId, updated);
      
      if (targetStatus == 'Approved') {
        LeaveNotificationService.notifyLeaveApproved(ref, updated);
      } else if (targetStatus == 'Rejected') {
        LeaveNotificationService.notifyLeaveRejected(ref, updated);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request status set to: $targetStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _employeeCancelLeave(LeaveModel leave) async {
    setState(() => _submitting = true);
    try {
      final updated = leave.copyWith(
        status: 'Cancelled',
        updatedAt: DateTime.now(),
      );
      await ref.read(leaveRepositoryProvider).updateLeave(leave.companyId, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request successfully cancelled.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
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
