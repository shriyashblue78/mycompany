import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/project_model.dart';
import '../../domain/models/project_tracker_config.dart';
import '../providers/project_tracker_provider.dart';
import '../widgets/edit_stage_dialog.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  String _getProjectCode(ProjectModel project) {
    if (project.projectName.toLowerCase().contains('mission beta')) {
      return 'MB-2025-001';
    }
    return 'PRJ-${project.projectId.toUpperCase().substring(0, 5)}';
  }

  String _getClientName(ProjectModel project) {
    if (project.projectName.toLowerCase().contains('mission beta')) {
      return 'John Doe';
    }
    return 'Internal';
  }

  Color _getStageColor(String name) {
    switch (name) {
      case 'Marketing':
        return Colors.green.shade700;
      case 'Design':
        return Colors.pink.shade700;
      case 'Purchase':
        return Colors.deepOrange.shade700;
      case 'Machining':
        return Colors.orange.shade700;
      case 'Assembly':
        return Colors.purple.shade700;
      case 'Quality':
        return Colors.teal.shade700;
      case 'Accounts':
        return Colors.indigo.shade700;
      default:
        return Colors.grey;
    }
  }

  // Helper to find start date/time of a stage from history
  DateTime? _getStageStartTime(String stageName, ProjectModel project) {
    try {
      final entry = project.stageHistory.firstWhere(
        (e) => e.department.toLowerCase() == stageName.toLowerCase() && e.status == 'In Progress',
      );
      return entry.timestamp;
    } catch (_) {
      return null;
    }
  }

  // Helper to find latest remarks for a stage from history
  String _getStageLatestRemarks(String stageName, ProjectModel project) {
    try {
      final entries = project.stageHistory
          .where((e) => e.department.toLowerCase() == stageName.toLowerCase())
          .toList();
      if (entries.isNotEmpty) {
        return entries.last.remarks;
      }
    } catch (_) {}
    return '';
  }

  // Helper to find all history entries for a specific stage
  List<StageHistoryEntry> _getStageHistoryLogs(String stageName, ProjectModel project) {
    return project.stageHistory
        .where((e) => e.department.toLowerCase() == stageName.toLowerCase())
        .toList();
  }

  // Helper to find active stage assignee
  String? _getActiveStageAssignee(ProjectModel project) {
    final current = project.currentStage;
    if (current == 'Marketing') return project.marketingStage.assignedUser;
    if (current == 'Design') return project.designStage.assignedUser;
    if (current == 'Purchase') return project.purchaseStage.assignedUser;
    if (current == 'Machining') return project.machiningStage.assignedUser;
    if (current == 'Assembly') return project.assemblyStage.assignedUser;
    if (current == 'Quality') return project.qualityStage.assignedUser;
    if (current == 'Accounts') return project.accountsStage.assignedUser;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = authState.selectedRole ?? 'Employee';

    final projectAsync = ref.watch(projectDetailsStreamProvider(projectId));

    return Theme(
      data: theme.copyWith(
        textTheme: GoogleFonts.ibmPlexMonoTextTheme(theme.textTheme),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Project Details'),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: [
            if (role == 'Owner' || role == 'HR' || role == 'Supervisor')
              projectAsync.when(
                data: (project) => project != null
                    ? Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            tooltip: 'Edit Project Metadata',
                            onPressed: () => context.push('/project-tracker/$projectId/edit', extra: project),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            tooltip: 'Delete Project',
                            onPressed: () => _confirmDelete(context, ref, project, user),
                          ),
                          const SizedBox(width: 8),
                        ],
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
        body: projectAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading details: $err')),
          data: (project) {
            if (project == null) {
              return const Center(child: Text('Project details not found.'));
            }

            if (user == null) {
              return const Center(child: Text('No authenticated user session.'));
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p20),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: ResponsiveLayout(
                      mobile: _buildMobileLayout(context, ref, project, user, theme, isDark),
                      tablet: _buildDesktopLayout(context, ref, project, user, theme, isDark),
                      desktop: _buildDesktopLayout(context, ref, project, user, theme, isDark),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, ProjectModel project, UserModel user, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetadataCard(project, theme, isDark),
        const SizedBox(height: AppSizes.p20),
        Text('Department Stages Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildTimelineList(context, ref, project, user, theme, isDark),
        const SizedBox(height: AppSizes.p20),
        _buildHistorySection(project, theme, isDark),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref, ProjectModel project, UserModel user, ThemeData theme, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildMetadataCard(project, theme, isDark),
              const SizedBox(height: AppSizes.p20),
              _buildHistorySection(project, theme, isDark),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.p24),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Department Stages Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTimelineList(context, ref, project, user, theme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataCard(ProjectModel project, ThemeData theme, bool isDark) {
    final statusColor = _getStatusColor(project.status);
    final activeAssignee = _getActiveStageAssignee(project);

    return Card(
      elevation: 0,
      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.projectName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    project.status,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Client / Code Corner Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_rounded, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('Client: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  Text(_getClientName(project), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 14),
                  Container(width: 1, height: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 14),
                  const Icon(Icons.tag_rounded, size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Code: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  Text(_getProjectCode(project), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ],
              ),
            ),
            const Divider(height: 28),
            Text(
              'Description',
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              project.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Start Date', DateFormat('MMM d, yyyy').format(project.startDate), Icons.calendar_today_rounded),
            _buildInfoRow(
              'End Date',
              project.endDate != null ? DateFormat('MMM d, yyyy').format(project.endDate!) : 'Not Specified',
              Icons.calendar_month_rounded,
            ),
            _buildInfoRow('Current Stage', project.currentStage, Icons.play_arrow_rounded),
            if (activeAssignee != null)
              _buildInfoRow('Active Stage Assignee', activeAssignee, Icons.person_outline_rounded),
            _buildInfoRow('Registered At', DateFormat('MMM d, yyyy h:mm a').format(project.createdAt), Icons.add_circle_outline_rounded),
            _buildInfoRow('Last Updated', DateFormat('MMM d, yyyy h:mm a').format(project.updatedAt), Icons.update_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList(BuildContext context, WidgetRef ref, ProjectModel project, UserModel user, ThemeData theme, bool isDark) {
    final stages = [
      _StageItem('Marketing', project.marketingStage),
      _StageItem('Design', project.designStage),
      _StageItem('Purchase', project.purchaseStage),
      _StageItem('Machining', project.machiningStage),
      _StageItem('Assembly', project.assemblyStage),
      _StageItem('Quality', project.qualityStage),
      _StageItem('Accounts', project.accountsStage),
    ];

    return Card(
      elevation: 0,
      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stages.length,
        itemBuilder: (context, idx) {
          final item = stages[idx];
          final isCurrent = project.currentStage == item.name;
          final hasPerm = _canUserEditStageAtThisMoment(item.name, project, user);
          final isLast = idx == stages.length - 1;
          final colColor = _getStageColor(item.name);

          // Get additional stage parameters
          final startedAt = _getStageStartTime(item.name, project);
          final remarks = _getStageLatestRemarks(item.name, project);
          final logs = _getStageHistoryLogs(item.name, project);

          return IntrinsicHeight(
            child: Container(
              decoration: BoxDecoration(
                color: isCurrent ? colColor.withOpacity(0.04) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isCurrent ? Border.all(color: colColor.withOpacity(0.3), width: 1) : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildStageTimelineIndicator(item.stage.status, isCurrent, theme),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: _getTimelineLineColor(item.stage.status),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colColor),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ACTIVE',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Status: ${item.stage.status}',
                                      style: TextStyle(
                                        color: _getStatusColor(item.stage.status == 'Pending' ? 'Planned' : item.stage.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (item.stage.assignedUser != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '• Responsible: ${item.stage.assignedUser}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                                // Show Start Date/Time
                                if (startedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Started: ${DateFormat('MMM d, yyyy h:mm a').format(startedAt)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                                // Show Completion Date/Time
                                if (item.stage.completedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Completed: ${DateFormat('MMM d, yyyy h:mm a').format(item.stage.completedAt!)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                                // Show Remarks
                                if (remarks.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Remarks: $remarks',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade800, fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ],
                                if (hasPerm && item.stage.status != 'Completed') ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _markStageAsCompletedDirectly(context, ref, project, item.name, item.stage),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                                    label: const Text('Mark as Completed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.success,
                                      side: const BorderSide(color: AppColors.success),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                                // Show nested Stage Transition history logs
                                if (logs.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  const Text('Stage Activity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
                                  ...logs.map((log) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '• ${DateFormat('MMM d, h:mm a').format(log.timestamp)} → ${log.status} (${log.responsiblePerson})',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  )),
                                ],
                              ],
                            ),
                          ),
                          if (hasPerm)
                            IconButton(
                              icon: Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                              tooltip: 'Edit Stage Status',
                              onPressed: () => _openEditStageDialog(context, project, item.name, item.stage),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistorySection(ProjectModel project, ThemeData theme, bool isDark) {
    if (project.stageHistory.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chronological Stage History',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: project.stageHistory.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                // Display latest first
                final entry = project.stageHistory[project.stageHistory.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${entry.department} → ${entry.status}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy h:mm a').format(entry.timestamp),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Responsible: ${entry.responsiblePerson}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                      ),
                      if (entry.remarks.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Remarks: ${entry.remarks}',
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade800, fontSize: 11.5, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTimelineIndicator(String status, bool isCurrent, ThemeData theme) {
    if (status == 'Completed') {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Colors.green,
        child: Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    } else if (status == 'In Progress') {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Colors.orange,
        child: Icon(Icons.sync_rounded, color: Colors.white, size: 14),
      );
    } else {
      return CircleAvatar(
        radius: 12,
        backgroundColor: isCurrent ? theme.colorScheme.primary.withOpacity(0.2) : Colors.grey.shade300,
        child: Icon(
          Icons.circle,
          color: isCurrent ? theme.colorScheme.primary : Colors.white,
          size: 8,
        ),
      );
    }
  }

  Color _getTimelineLineColor(String status) {
    if (status == 'Completed') {
      return Colors.green;
    } else if (status == 'In Progress') {
      return Colors.orange;
    } else {
      return Colors.grey.shade300;
    }
  }

  bool _canUserEditStageAtThisMoment(String stageName, ProjectModel project, UserModel user) {
    if (ProjectTrackerConfig.managerRoles.contains(user.role)) return true;

    // Department employees can only edit their stage if it is the current active stage
    if (project.currentStage.toLowerCase() != stageName.toLowerCase()) return false;

    return ProjectTrackerConfig.canEditStage(user.role, user.department, stageName);
  }

  void _openEditStageDialog(BuildContext context, ProjectModel project, String departmentName, ProjectStage stage) {
    showDialog(
      context: context,
      builder: (ctx) => EditStageDialog(
        project: project,
        departmentName: departmentName,
        stage: stage,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ProjectModel project, UserModel? user) {
    if (user == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to permanently delete project "${project.projectName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final companyId = project.companyId;
                await ref.read(projectTrackerRepositoryProvider).deleteProject(companyId, project.projectId, user);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project deleted successfully.'), backgroundColor: Colors.green),
                  );
                  context.pop(); // Go back to dashboard
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
      case 'Finished':
        return Colors.green;
      case 'In Progress':
      case 'Active':
        return Colors.orange;
      case 'On Hold':
      case 'Blocked':
      case 'Delayed':
      case 'Attention Required':
      case 'Rejected':
        return Colors.red;
      case 'Planned':
      case 'Not Started':
      case 'Pending':
      default:
        return Colors.grey;
    }
  }

  Future<void> _markStageAsCompletedDirectly(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
    String stageName,
    ProjectStage stage,
  ) async {
    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    final user = authState.user;

    if (companyId == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User session not found.')),
      );
      return;
    }

    try {
      final updatedStage = ProjectStage(
        status: 'Completed',
        assignedUser: stage.assignedUser ?? user.name,
        completedAt: DateTime.now(),
      );

      ProjectModel updatedProject;
      final deptNameLower = stageName.trim().toLowerCase();

      if (deptNameLower == 'marketing') {
        updatedProject = project.copyWith(marketingStage: updatedStage);
      } else if (deptNameLower == 'design') {
        updatedProject = project.copyWith(designStage: updatedStage);
      } else if (deptNameLower == 'purchase') {
        updatedProject = project.copyWith(purchaseStage: updatedStage);
      } else if (deptNameLower == 'machining') {
        updatedProject = project.copyWith(machiningStage: updatedStage);
      } else if (deptNameLower == 'assembly') {
        updatedProject = project.copyWith(assemblyStage: updatedStage);
      } else if (deptNameLower == 'quality') {
        updatedProject = project.copyWith(qualityStage: updatedStage);
      } else if (deptNameLower == 'accountant' || deptNameLower == 'accounts') {
        updatedProject = project.copyWith(accountsStage: updatedStage);
      } else {
        throw Exception('Unknown department stage: $stageName');
      }

      final newHistoryEntry = StageHistoryEntry(
        department: stageName,
        status: 'Completed',
        responsiblePerson: stage.assignedUser ?? user.name,
        timestamp: DateTime.now(),
        remarks: 'Quick marked as Completed by ${user.name}.',
      );

      final updatedHistory = List<StageHistoryEntry>.from(updatedProject.stageHistory)..add(newHistoryEntry);
      updatedProject = updatedProject.copyWith(stageHistory: updatedHistory);

      await ref.read(projectTrackerRepositoryProvider).updateProject(companyId, updatedProject, user);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$stageName stage marked as Completed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stage: $e')),
        );
      }
    }
  }
}

class _StageItem {
  final String name;
  final ProjectStage stage;

  _StageItem(this.name, this.stage);
}
