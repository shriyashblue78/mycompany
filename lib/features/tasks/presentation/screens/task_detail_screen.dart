import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../domain/models/task_model.dart';
import '../providers/tasks_provider.dart';
import '../../../tooling/domain/models/tool_model.dart';
import '../../../tooling/presentation/providers/tool_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/utils/download_helper.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _remarkController = TextEditingController();
  final _toolingRemarkController = TextEditingController();
  final _rejectionReasonFormController = TextEditingController();
  
  int _selectedHours = 0;
  int _selectedMinutes = 0;
  bool? _toolingRequired;
  final List<String> _selectedToolIds = [];
  final List<String> _selectedToolNames = [];

  double? _localProgress;
  bool _initialized = false;
  bool _submitting = false;

  @override
  void dispose() {
    _remarkController.dispose();
    _toolingRemarkController.dispose();
    _rejectionReasonFormController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    final taskAsync = ref.watch(taskDetailsStreamProvider(widget.taskId));
    final employeesAsync = ref.watch(companyEmployeesProvider);
    final theme = Theme.of(context);

    final role = user.role;
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    return taskAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Task Details...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (task) {
        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Task Not Found')),
            body: const Center(child: Text('The requested task does not exist or has been deleted.')),
          );
        }

        if (!_initialized) {
          _localProgress = task.progress;
          _initialized = true;
        }

        return employeesAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(task.title)),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Scaffold(
            appBar: AppBar(title: Text(task.title)),
            body: Center(child: Text('Error loading staff details: $err')),
          ),
          data: (employees) {
            final assignee = employees.where((e) => e.employeeId == task.assignedToEmployeeId).firstOrNull;
            final assigneeName = assignee != null ? assignee.name : 'Unknown (${task.assignedToEmployeeId})';

            final isMobile = ResponsiveLayout.isMobile(context);

            final bodyContent = isMobile
                ? _buildMobileLayout(context, theme, task, assigneeName, isManager, user.companyId, user.uid)
                : _buildDesktopLayout(context, theme, task, assigneeName, isManager, user.companyId, user.uid);

            return ResponsiveScaffold(
              appBar: AppBar(
                title: Text(task.title),
                elevation: 0,
                backgroundColor: theme.colorScheme.surface,
                iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
                actions: [
                  if (isManager && task.status != 'Cancelled') ...[
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      tooltip: 'Edit Task',
                      onPressed: () => context.push('/tasks/${task.taskId}/edit', extra: task),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      tooltip: 'Cancel Task',
                      onPressed: () => _showCancelDialog(context, task, user.companyId),
                    ),
                  ],
                ],
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
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    TaskModel task,
    String assigneeName,
    bool isManager,
    String companyId,
    String userUid,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoPanel(theme, task, assigneeName),
          const SizedBox(height: AppSizes.p24),
          _buildUpdatePanel(theme, task, isManager, companyId, userUid),
          const SizedBox(height: AppSizes.p24),
          _buildRemarksPanel(theme, task, isMobile: true),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    TaskModel task,
    String assigneeName,
    bool isManager,
    String companyId,
    String userUid,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Info panel & Update progress
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoPanel(theme, task, assigneeName),
                  const SizedBox(height: AppSizes.p24),
                  _buildUpdatePanel(theme, task, isManager, companyId, userUid),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSizes.p24),

          // Right column: Remarks list & add remark
          Expanded(
            flex: 2,
            child: _buildRemarksPanel(theme, task, isMobile: false),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeData theme, TaskModel task, String assigneeName) {
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(task.status);
    final priorityColor = _getPriorityColor(task.priority);

    final startStr = '${task.startDate.year}-${task.startDate.month.toString().padLeft(2, '0')}-${task.startDate.day.toString().padLeft(2, '0')}';
    final dueStr = '${task.dueDate.year}-${task.dueDate.month.toString().padLeft(2, '0')}-${task.dueDate.day.toString().padLeft(2, '0')}';
    
    String _formatDate(DateTime? dt) {
      if (dt == null) return 'N/A';
      final dStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final tStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$dStr $tStr';
    }

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
            // Status and priority badges
            Row(
              children: [
                _buildBadge('Status', task.status, statusColor),
                const SizedBox(width: AppSizes.p12),
                _buildBadge('Priority', task.priority, priorityColor),
                if (task.completionTiming != null) ...[
                  const SizedBox(width: AppSizes.p12),
                  _buildBadge(
                    'Timing',
                    task.completionTiming!,
                    task.completionTiming == 'Early'
                        ? Colors.teal
                        : (task.completionTiming == 'Late' ? AppColors.error : AppColors.success),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.p20),

            // Description
            Text(
              'Description',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              task.description.isNotEmpty ? task.description : 'No description provided.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.4),
            ),
            const Divider(height: AppSizes.p32),

            // Key info items
            _buildDetailRow(context, 'Assigned To', assigneeName, Icons.person_outline_rounded),
            _buildDetailRow(context, 'Assigned By', task.assignedBy, Icons.assignment_ind_outlined),
            _buildDetailRow(context, 'Department', task.department, Icons.corporate_fare_rounded),
            
            if (task.machineName != null) 
              _buildDetailRow(context, 'Machine', '${task.machineName} (${task.machineCode ?? ""})', Icons.precision_manufacturing_outlined),
            
            if (task.programName != null && task.programName!.isNotEmpty)
              _buildDetailRow(context, 'Program', task.programName!, Icons.code_rounded),
            
            _buildDetailRow(context, 'Created Start Date', startStr, Icons.play_arrow_outlined),
            _buildDetailRow(context, 'Original Due Date', dueStr, Icons.access_time_rounded),
            
            if (task.taskStartTime != null)
              _buildDetailRow(context, 'Task Start Time', _formatDate(task.taskStartTime), Icons.play_circle_fill_rounded),
            
            if (task.deadlineTime != null)
              _buildDetailRow(context, 'Task Deadline', _formatDate(task.deadlineTime), Icons.timer_rounded),

            if (task.estimatedDurationMinutes != null)
              _buildDetailRow(context, 'Est. Duration', _formatDuration(task.estimatedDurationMinutes!), Icons.timer_outlined),
            
            if (task.allowedDurationMinutes != null)
              _buildDetailRow(context, 'Allowed Duration', '${_formatDuration(task.allowedDurationMinutes!)} (incl. 10m buffer)', Icons.hourglass_full_rounded),

            if (task.actualCompletionTime != null || task.completedDate != null)
              _buildDetailRow(context, 'Completed On', _formatDate(task.actualCompletionTime ?? task.completedDate), Icons.check_circle_outline_rounded),

            if (task.totalTimeTakenMinutes != null)
              _buildDetailRow(context, 'Total Time Taken', _formatDuration(task.totalTimeTakenMinutes!), Icons.timelapse_rounded),

            if (task.completionTiming == 'Late' && task.lateDurationMinutes != null)
              _buildDetailRow(context, 'Late Duration', _formatDuration(task.lateDurationMinutes!), Icons.warning_amber_rounded),

            if (task.toolingRequired != null)
              _buildDetailRow(context, 'Tooling Required', task.toolingRequired! ? 'Yes' : 'No', Icons.build_outlined),
            if (task.selectedToolNames != null && task.selectedToolNames!.isNotEmpty)
              _buildDetailRow(context, 'Selected Tools', task.selectedToolNames!.join(', '), Icons.handyman_outlined),
            if (task.toolingRemark != null && task.toolingRemark!.isNotEmpty)
              _buildDetailRow(context, 'Tooling Remark', task.toolingRemark!, Icons.chat_bubble_outline_rounded),
            
            if (task.drawingPhotoUrl != null) ...[
              const SizedBox(height: AppSizes.p16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Drawing/Task Photo',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.blue),
                    tooltip: 'Download Photo',
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saving image to gallery...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        await downloadFile(
                          task.drawingPhotoUrl!,
                          'task_${task.taskId}_drawing.jpg',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Image saved to gallery successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save image: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p8),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog.fullscreen(
                      backgroundColor: Colors.black,
                      child: Stack(
                        children: [
                          Center(
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Image.network(
                                task.drawingPhotoUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                                },
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Text('Could not load image', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: SafeArea(
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  child: Image.network(
                    task.drawingPhotoUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Text('Could not load photo'),
                  ),
                ),
              ),
            ],

            if (task.status == 'Rejected' && task.rejectionReason != null) ...[
              const SizedBox(height: AppSizes.p24),
              Container(
                padding: const EdgeInsets.all(AppSizes.p16),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  border: Border.all(color: AppColors.error.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(
                          'Task Rejected',
                          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Rejected by: ${task.rejectedByName ?? "Employee"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Reason: ${task.rejectionReason}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon) {
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

  Widget _buildUpdatePanel(ThemeData theme, TaskModel task, bool isManager, String companyId, String userUid) {
    final isDark = theme.brightness == Brightness.dark;
    final isCancelled = task.status == 'Cancelled';
    final isCompleted = task.status == 'Completed';
    final isPending = task.status == 'Pending Acceptance';

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
              'Progress & Timing Updates',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p16),

            if (isCompleted) ...[
              TaskCompletedBanner(task: task),
              const SizedBox(height: AppSizes.p16),
            ] else if (!isCancelled && !isPending && task.status != 'Rejected') ...[
              TaskCountdownBanner(task: task),
              const SizedBox(height: AppSizes.p16),
            ],

            // Progress details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Progress'),
                Text(
                  '${_localProgress?.toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (isPending) ...[
              if (task.assignedToUid == userUid) ...[
                const Text(
                  'You have been assigned this task. Please input task estimate and tooling details to proceed.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Estimated Completion Time *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedHours,
                        decoration: const InputDecoration(
                          labelText: 'Hours',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(25, (i) => i).map((h) {
                          return DropdownMenuItem<int>(
                            value: h,
                            child: Text('$h hrs'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedHours = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Minutes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(60, (i) => i).map((m) {
                          return DropdownMenuItem<int>(
                            value: m,
                            child: Text('$m min'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMinutes = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tooling Required? *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('YES'),
                      selected: _toolingRequired == true,
                      onSelected: (selected) {
                        setState(() {
                          _toolingRequired = selected ? true : null;
                        });
                      },
                      selectedColor: AppColors.success.withAlpha(50),
                      labelStyle: TextStyle(
                        color: _toolingRequired == true ? AppColors.success : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('NO'),
                      selected: _toolingRequired == false,
                      onSelected: (selected) {
                        setState(() {
                          _toolingRequired = selected ? false : null;
                        });
                      },
                      selectedColor: AppColors.error.withAlpha(50),
                      labelStyle: TextStyle(
                        color: _toolingRequired == false ? AppColors.error : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_toolingRequired == true) ...[
                  ref.watch(companyToolsStreamProvider).when(
                    data: (tools) {
                      final activeTools = tools.where((t) => t.status == 'Active').toList();
                      if (activeTools.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No active tools found in Tooling Master. Cannot proceed.', style: TextStyle(color: AppColors.error)),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Tools Required *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: activeTools.length,
                              itemBuilder: (ctx, idx) {
                                final tool = activeTools[idx];
                                final isChecked = _selectedToolIds.contains(tool.toolId);
                                return CheckboxListTile(
                                  title: Text('${tool.toolName} (${tool.toolCode})'),
                                  subtitle: Text('Location: ${tool.location}'),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedToolIds.add(tool.toolId);
                                        _selectedToolNames.add(tool.toolName);
                                      } else {
                                        _selectedToolIds.remove(tool.toolId);
                                        _selectedToolNames.remove(tool.toolName);
                                      }
                                    });
                                  },
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error loading tools: $err', style: const TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _toolingRemarkController,
                    decoration: const InputDecoration(
                      labelText: 'Tooling Remark (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!_validateForm(isAccept: true)) return;
                            final totalMinutes = _selectedHours * 60 + _selectedMinutes;
                            _acceptTaskWithTooling(
                              task,
                              companyId,
                              totalMinutes,
                              _selectedToolIds,
                              _selectedToolNames,
                              _toolingRemarkController.text.trim(),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Accept Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(context, task, companyId),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject Task'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_toolingRequired == false) ...[
                  const Text(
                    'No tooling required. Click below to accept the task or submit rejection.',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rejectionReasonFormController,
                    decoration: const InputDecoration(
                      labelText: 'Rejection Reason/Remark (Required only if rejecting)',
                      border: OutlineInputBorder(),
                      hintText: 'Provide reason if rejecting task...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final totalMinutes = _selectedHours * 60 + _selectedMinutes;
                            if (totalMinutes < 1 || totalMinutes > 1440) {
                              showFeedbackSnackBar(
                                context: context,
                                message: 'Estimated completion time must be between 1 minute and 24 hours.',
                                isError: true,
                              );
                              return;
                            }
                            _acceptTask(task, companyId, totalMinutes);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Accept Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final reason = _rejectionReasonFormController.text.trim();
                            if (reason.isEmpty) {
                              showFeedbackSnackBar(
                                context: context,
                                message: 'Please provide a rejection reason.',
                                isError: true,
                              );
                              return;
                            }
                            final totalMinutes = _selectedHours * 60 + _selectedMinutes;
                            _rejectTaskWithReason(task, companyId, totalMinutes, reason);
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject Task'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                const Text(
                  'Waiting for assignee to accept the task.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ],
            ] else if (!isCancelled && !isCompleted && task.status != 'Rejected') ...[
              Slider(
                value: _localProgress ?? 0.0,
                min: 0.0,
                max: 100.0,
                divisions: 20,
                label: '${_localProgress?.toInt()}%',
                onChanged: (val) {
                  setState(() {
                    _localProgress = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final deadline = task.deadlineTime ?? task.dueDate;
                final isCurrentlyLate = DateTime.now().isAfter(deadline);
                final completeButtonText = isCurrentlyLate ? 'Task Completed Late' : 'Task Completed';
                final completeButtonColor = isCurrentlyLate ? Colors.orange.shade800 : AppColors.success;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _updateProgress(task, companyId),
                      child: const Text('Update Progress'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _markCompleted(task, companyId),
                      icon: Icon(isCurrentlyLate ? Icons.warning_amber_rounded : Icons.done_all_rounded),
                      label: Text(completeButtonText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completeButtonColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                );
              }),
            ] else ...[
              // Read-only progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_localProgress ?? 0.0) / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(task.status == 'Completed' ? AppColors.success : theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCompleted
                    ? 'This task has been completed and is locked.'
                    : (task.status == 'Rejected' ? 'This task was rejected by the assignee.' : 'This task has been cancelled and is inactive.'),
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksPanel(ThemeData theme, TaskModel task, {bool isMobile = false}) {
    final isDark = theme.brightness == Brightness.dark;
    final isCancelled = task.status == 'Cancelled';

    Widget listContent = task.remarks.isEmpty
        ? const Center(child: Text('No remarks added yet.', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            shrinkWrap: isMobile,
            physics: isMobile ? const NeverScrollableScrollPhysics() : null,
            itemCount: task.remarks.length,
            itemBuilder: (context, index) {
              final remark = task.remarks[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200),
                ),
                child: Text(
                  remark,
                  style: theme.textTheme.bodyMedium,
                ),
              );
            },
          );

    if (isMobile) {
      if (task.remarks.isEmpty) {
        listContent = const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No remarks added yet.', style: TextStyle(color: Colors.grey))),
        );
      }
    } else {
      listContent = Expanded(child: listContent);
    }

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
              'Remarks & Activity Logs',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p12),

            listContent,

            if (!isCancelled) ...[
              const Divider(height: 24),
              // Add Remark Field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _remarkController,
                      decoration: InputDecoration(
                        hintText: 'Add progress remark...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _addRemark(task),
                    icon: const Icon(Icons.send_rounded),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateProgress(TaskModel task, String companyId) async {
    setState(() => _submitting = true);
    try {
      final updated = task.copyWith(
        progress: _localProgress ?? 0.0,
        status: (_localProgress ?? 0.0) == 100.0 ? 'Completed' : 'In Progress',
        completedDate: (_localProgress ?? 0.0) == 100.0 ? DateTime.now() : null,
      );
      await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update progress: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _markCompleted(TaskModel task, String companyId) async {
    final authState = ref.read(authProvider);
    final userUid = authState.user?.uid ?? '';
    if (userUid != task.assignedToUid) {
      showFeedbackSnackBar(
        context: context,
        message: 'Security Violation: Only the assigned employee can complete this task.',
        isError: true,
      );
      return;
    }

    final actualCompletionTime = DateTime.now();
    final startTime = task.taskStartTime ?? task.startDate;
    final totalTimeTakenMinutes = actualCompletionTime.difference(startTime).inMinutes;

    final deadline = task.deadlineTime ?? task.dueDate;
    final isPastDeadline = actualCompletionTime.isAfter(deadline);

    if (isPastDeadline) {
      final lateDurationMinutes = actualCompletionTime.difference(deadline).inMinutes;
      _showLateCompletionDialog(task, companyId, actualCompletionTime, totalTimeTakenMinutes, lateDurationMinutes);
    } else {
      setState(() => _submitting = true);
      try {
        final userName = authState.user?.name ?? 'Employee';
        final isEarly = actualCompletionTime.isBefore(deadline);
        final completionTiming = isEarly ? 'Early' : 'On Time';

        final updated = task.copyWith(
          status: 'Completed',
          progress: 100.0,
          completedDate: actualCompletionTime,
          actualCompletionTime: actualCompletionTime,
          totalTimeTakenMinutes: totalTimeTakenMinutes,
          completionTiming: completionTiming,
        );

        await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
        await TaskNotificationService.notifyTaskStatusChanged(ref, updated, 'Completed', userName);

        setState(() {
          _localProgress = 100.0;
        });

        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: isEarly
                ? 'Excellent! Completed before the given time.'
                : 'Task completed on time.',
          );
        }
      } catch (e) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Failed to complete task: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  void _showLateCompletionDialog(
    TaskModel task,
    String companyId,
    DateTime actualCompletionTime,
    int totalTimeTakenMinutes,
    int lateDurationMinutes,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ResponsiveDialog(
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text('Task Completed Late'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This task is late by ${_formatDuration(lateDurationMinutes)}.',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                ),
                const SizedBox(height: 12),
                const Text('Please enter a completion reason/remark before completing:'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Late Reason / Remark *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Tool setup took additional time...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final remark = reasonController.text.trim();
                  if (remark.isEmpty) {
                    showFeedbackSnackBar(
                      context: context,
                      message: 'Late completion reason is required.',
                      isError: true,
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  setState(() => _submitting = true);
                  try {
                    final authState = ref.read(authProvider);
                    final userName = authState.user?.name ?? 'Employee';

                    final updated = task.copyWith(
                      status: 'Completed',
                      progress: 100.0,
                      completedDate: actualCompletionTime,
                      actualCompletionTime: actualCompletionTime,
                      totalTimeTakenMinutes: totalTimeTakenMinutes,
                      completionTiming: 'Late',
                      lateDurationMinutes: lateDurationMinutes,
                      lateReason: remark,
                    );

                    await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
                    await TaskNotificationService.notifyTaskStatusChanged(ref, updated, 'Completed', userName);

                    setState(() {
                      _localProgress = 100.0;
                    });

                    if (mounted) {
                      showFeedbackSnackBar(
                        context: context,
                        message: 'Task marked as completed late.',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      showFeedbackSnackBar(
                        context: context,
                        message: 'Failed to complete task: $e',
                        isError: true,
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
                child: const Text('Submit & Complete'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addRemark(TaskModel task) async {
    final text = _remarkController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final authState = ref.read(authProvider);
      final senderName = authState.userName ?? 'Staff';
      final formattedRemark = '$senderName (${DateTime.now().toString().substring(0, 16)}): $text';

      final updated = task.copyWith(
        remarks: [...task.remarks, formattedRemark],
      );
      await ref.read(taskRepositoryProvider).updateTask(task.companyId, updated);
      _remarkController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remark added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add remark: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _showCancelDialog(BuildContext context, TaskModel task, String companyId) {
    showDialog(
      context: context,
      builder: (context) {
        return ResponsiveDialog(
          child: AlertDialog(
            title: const Text('Cancel Task?'),
            content: const Text('Are you sure you want to cancel this task? This will lock the task progress and freeze updates.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  setState(() => _submitting = true);
                  try {
                    final updated = task.copyWith(status: 'Cancelled');
                    await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task cancelled successfully.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to cancel task: $e')),
                    );
                  } finally {
                    setState(() => _submitting = false);
                  }
                },
                child: const Text('Yes, Cancel Task', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, TaskModel task, String companyId) {
    final authState = ref.read(authProvider);
    final userUid = authState.user?.uid ?? '';
    if (userUid != task.assignedToUid) {
      showFeedbackSnackBar(
        context: context,
        message: 'Security Violation: Only the assigned employee can perform this action.',
        isError: true,
      );
      return;
    }

    final _reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return ResponsiveDialog(
          child: AlertDialog(
            title: const Text('Reject Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason for rejecting this task.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Rejection reason...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                onPressed: () async {
                  if (_reasonController.text.trim().isEmpty) return;
                  Navigator.of(context).pop();
                  setState(() => _submitting = true);
                  try {
                    final userName = authState.user?.name ?? 'Employee';

                    final updated = task.copyWith(
                      status: 'Rejected',
                      rejectedByUid: userUid,
                      rejectedByName: userName,
                      rejectedAt: DateTime.now(),
                      rejectionReason: _reasonController.text.trim(),
                    );
                    await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
                    await TaskNotificationService.notifyTaskStatusChanged(ref, updated, 'Rejected', userName);
                    
                    if (mounted) {
                      showFeedbackSnackBar(
                        context: context,
                        message: 'Task rejected.',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      showFeedbackSnackBar(
                        context: context,
                        message: 'Failed to reject task: $e',
                        isError: true,
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
                child: const Text('Reject'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _acceptTask(TaskModel task, String companyId, int duration) async {
    final authState = ref.read(authProvider);
    final userUid = authState.user?.uid ?? '';
    if (userUid != task.assignedToUid) {
      showFeedbackSnackBar(
        context: context,
        message: 'Security Violation: Only the assigned employee can perform this action.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final userName = authState.user?.name ?? 'Employee';
      final now = DateTime.now();
      const bufferMinutes = 10;
      final allowedDurationMinutes = duration + bufferMinutes;
      final deadlineTime = now.add(Duration(minutes: allowedDurationMinutes));

      final updated = task.copyWith(
        status: 'Accepted',
        estimatedDurationMinutes: duration,
        toolingRequired: false,
        taskStartTime: now,
        bufferMinutes: bufferMinutes,
        allowedDurationMinutes: allowedDurationMinutes,
        deadlineTime: deadlineTime,
      );
      await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
      await TaskNotificationService.notifyTaskStatusChanged(ref, updated, 'Accepted', userName);

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Task accepted successfully! Countdown started.',
        );
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to accept task: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hrs ${hrs == 1 ? "hour" : "hours"}';
    return '$hrs ${hrs == 1 ? "hour" : "hours"} $mins min';
  }

  bool _validateForm({required bool isAccept}) {
    final totalMinutes = _selectedHours * 60 + _selectedMinutes;
    if (totalMinutes < 1 || totalMinutes > 1440) {
      showFeedbackSnackBar(
        context: context,
        message: 'Estimated completion time must be between 1 minute and 24 hours.',
        isError: true,
      );
      return false;
    }

    if (_toolingRequired == null) {
      showFeedbackSnackBar(
        context: context,
        message: 'Please specify if tooling is required.',
        isError: true,
      );
      return false;
    }

    if (_toolingRequired == true && isAccept) {
      if (_selectedToolIds.isEmpty) {
        showFeedbackSnackBar(
          context: context,
          message: 'Please select at least one tool.',
          isError: true,
        );
        return false;
      }
    }

    if (_toolingRequired == false) {
      if (_rejectionReasonFormController.text.trim().isEmpty) {
        showFeedbackSnackBar(
          context: context,
          message: 'Please provide a reason/remark for rejection.',
          isError: true,
        );
        return false;
      }
    }

    return true;
  }

  void _acceptTaskWithTooling(
    TaskModel task,
    String companyId,
    int duration,
    List<String> toolIds,
    List<String> toolNames,
    String toolingRemark,
  ) async {
    final authState = ref.read(authProvider);
    final userUid = authState.user?.uid ?? '';
    if (userUid != task.assignedToUid) {
      showFeedbackSnackBar(
        context: context,
        message: 'Security Violation: Only the assigned employee can accept this task.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final userName = authState.user?.name ?? 'Employee';
      final now = DateTime.now();
      const bufferMinutes = 10;
      final allowedDurationMinutes = duration + bufferMinutes;
      final deadlineTime = now.add(Duration(minutes: allowedDurationMinutes));

      final updated = task.copyWith(
        status: 'Accepted',
        estimatedDurationMinutes: duration,
        toolingRequired: true,
        selectedToolIds: toolIds,
        selectedToolNames: toolNames,
        toolingRemark: toolingRemark,
        taskStartTime: now,
        bufferMinutes: bufferMinutes,
        allowedDurationMinutes: allowedDurationMinutes,
        deadlineTime: deadlineTime,
      );
      await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
      await TaskNotificationService.notifyTaskStatusChanged(ref, updated, 'Accepted', userName);

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Task accepted successfully! Countdown started.',
        );
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to accept task: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _rejectTaskWithReason(
    TaskModel task,
    String companyId,
    int duration,
    String reason,
  ) async {
    final authState = ref.read(authProvider);
    final userUid = authState.user?.uid ?? '';
    if (userUid != task.assignedToUid) {
      showFeedbackSnackBar(
        context: context,
        message: 'Security Violation: Only the assigned employee can reject this task.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final userName = authState.user?.name ?? 'Employee';
      final updated = task.copyWith(
        status: 'Rejected',
        estimatedDurationMinutes: duration,
        toolingRequired: false,
        rejectionReason: reason,
        rejectedByUid: userUid,
        rejectedByName: userName,
        rejectedAt: DateTime.now(),
      );
      await ref.read(taskRepositoryProvider).updateTask(companyId, updated);
      await TaskNotificationService.notifyTaskStatusChanged(ref, updated, 'Rejected', userName);

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Task rejected successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to reject task: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return AppColors.error;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return AppColors.warning;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'In Progress':
        return AppColors.info;
      case 'Accepted':
        return Colors.green.shade600;
      case 'On Hold':
        return Colors.purple;
      case 'Rejected':
        return AppColors.error;
      case 'Cancelled':
        return Colors.grey.shade600;
      case 'Pending Acceptance':
        return Colors.blue.shade600;
      default:
        return AppColors.warning;
    }
  }
}

class TaskCountdownBanner extends StatefulWidget {
  final TaskModel task;
  const TaskCountdownBanner({super.key, required this.task});

  @override
  State<TaskCountdownBanner> createState() => _TaskCountdownBannerState();
}

class _TaskCountdownBannerState extends State<TaskCountdownBanner> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDurationHMS(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours >= 24) {
      final days = hours ~/ 24;
      final remHours = hours % 24;
      return '${days}d ${remHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final deadline = task.deadlineTime ?? task.dueDate;
    final startTime = task.taskStartTime ?? task.startDate;
    final isOverdue = _now.isAfter(deadline);
    final diff = isOverdue ? _now.difference(deadline) : deadline.difference(_now);
    final timeTaken = _now.difference(startTime);

    final theme = Theme.of(context);
    final bgGradient = isOverdue
        ? const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)])
        : LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(210)]);

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: [
          BoxShadow(
            color: (isOverdue ? Colors.red : theme.colorScheme.primary).withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOverdue ? Icons.error_outline_rounded : Icons.timer_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOverdue ? 'STATUS: OVERDUE / LATE' : 'STATUS: RUNNING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue by ${_formatDurationHMS(diff)}' : 'Countdown: ${_formatDurationHMS(diff)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOverdue ? Icons.error_outline_rounded : Icons.timer_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOverdue ? 'STATUS: OVERDUE / LATE' : 'STATUS: RUNNING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue by ${_formatDurationHMS(diff)}' : 'Countdown: ${_formatDurationHMS(diff)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white30, height: 1),
          const SizedBox(height: 12),
          isCompact
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMetric('Est. Time', task.estimatedDurationMinutes != null ? '${task.estimatedDurationMinutes}m (+10m buf)' : 'N/A')),
                        Expanded(child: _buildMetric('Start Time', _formatDateTime(startTime))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildMetric('Deadline', _formatDateTime(deadline))),
                        Expanded(child: _buildMetric('Time Taken', '${timeTaken.inMinutes} mins')),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMetric('Est. Time', task.estimatedDurationMinutes != null ? '${task.estimatedDurationMinutes}m (+10m buf)' : 'N/A')),
                    Expanded(child: _buildMetric('Start Time', _formatDateTime(startTime))),
                    Expanded(child: _buildMetric('Deadline', _formatDateTime(deadline))),
                    Expanded(child: _buildMetric('Time Taken', '${timeTaken.inMinutes} mins')),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('Could not load image', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCompletedBanner extends StatelessWidget {
  final TaskModel task;
  const TaskCompletedBanner({super.key, required this.task});

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final timing = task.completionTiming ?? 'On Time';
    Color bannerColor = AppColors.success;
    IconData bannerIcon = Icons.check_circle_rounded;
    String timingTitle = 'Task Completed On Time';

    if (timing == 'Early') {
      bannerColor = Colors.teal;
      bannerIcon = Icons.stars_rounded;
      timingTitle = 'Task Completed Early!';
    } else if (timing == 'Late') {
      bannerColor = Colors.orange.shade800;
      bannerIcon = Icons.warning_amber_rounded;
      timingTitle = 'Task Completed Late';
    }

    final totalTime = task.totalTimeTakenMinutes ?? 0;
    final totalHrs = totalTime ~/ 60;
    final totalMins = totalTime % 60;
    final totalTimeStr = totalHrs > 0 ? '$totalHrs hrs $totalMins mins' : '$totalMins mins';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: bannerColor.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: bannerColor.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(bannerIcon, color: bannerColor, size: 24),
              const SizedBox(width: 10),
              Text(
                timingTitle,
                style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  timing.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Completion Time', _formatDateTime(task.actualCompletionTime ?? task.completedDate))),
              Expanded(child: _buildInfoItem('Total Time Taken', totalTimeStr)),
              if (timing == 'Late' && task.lateDurationMinutes != null)
                Expanded(child: _buildInfoItem('Late Duration', '${task.lateDurationMinutes} mins')),
            ],
          ),
          if (timing == 'Late' && task.lateReason != null && task.lateReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Late Completion Reason / Remark:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: bannerColor),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(150),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: bannerColor.withAlpha(40)),
              ),
              child: Text(
                task.lateReason!,
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
