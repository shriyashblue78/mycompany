import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/project_model.dart';
import '../providers/project_tracker_provider.dart';

class EditStageDialog extends ConsumerStatefulWidget {
  final ProjectModel project;
  final String departmentName; // 'Marketing', 'Design', etc.
  final ProjectStage stage;

  const EditStageDialog({
    super.key,
    required this.project,
    required this.departmentName,
    required this.stage,
  });

  @override
  ConsumerState<EditStageDialog> createState() => _EditStageDialogState();
}

class _EditStageDialogState extends ConsumerState<EditStageDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedStatus;
  late TextEditingController _assigneeController;
  late TextEditingController _remarksController;
  DateTime? _completedAt;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.stage.status;
    _assigneeController = TextEditingController(text: widget.stage.assignedUser ?? '');
    _remarksController = TextEditingController();
    _completedAt = widget.stage.completedAt;
  }

  @override
  void dispose() {
    _assigneeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectCompletionDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _completedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _completedAt = picked;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    final user = authState.user;

    if (companyId == null || user == null) {
      setState(() {
        _saving = false;
        _errorMessage = 'Unauthorized context. User session not found.';
      });
      return;
    }

    try {
      // 1. Create updated stage
      final updatedStage = ProjectStage(
        status: _selectedStatus,
        assignedUser: _assigneeController.text.trim().isEmpty ? null : _assigneeController.text.trim(),
        completedAt: _selectedStatus == 'Completed' ? (_completedAt ?? DateTime.now()) : null,
      );

      // 2. Insert stage into correct field of ProjectModel
      ProjectModel updatedProject;
      final deptNameLower = widget.departmentName.trim().toLowerCase();

      if (deptNameLower == 'marketing') {
        updatedProject = widget.project.copyWith(marketingStage: updatedStage);
      } else if (deptNameLower == 'design') {
        updatedProject = widget.project.copyWith(designStage: updatedStage);
      } else if (deptNameLower == 'purchase') {
        updatedProject = widget.project.copyWith(purchaseStage: updatedStage);
      } else if (deptNameLower == 'machining') {
        updatedProject = widget.project.copyWith(machiningStage: updatedStage);
      } else if (deptNameLower == 'assembly') {
        updatedProject = widget.project.copyWith(assemblyStage: updatedStage);
      } else if (deptNameLower == 'quality') {
        updatedProject = widget.project.copyWith(qualityStage: updatedStage);
      } else if (deptNameLower == 'accountant' || deptNameLower == 'accounts') {
        updatedProject = widget.project.copyWith(accountsStage: updatedStage);
      } else {
        throw Exception('Unknown department stage: ${widget.departmentName}');
      }

      // 3. Create StageHistoryEntry and append to history
      final newHistoryEntry = StageHistoryEntry(
        department: widget.departmentName,
        status: _selectedStatus,
        responsiblePerson: _assigneeController.text.trim().isNotEmpty
            ? _assigneeController.text.trim()
            : user.name,
        timestamp: DateTime.now(),
        remarks: _remarksController.text.trim().isEmpty
            ? 'Stage status updated to $_selectedStatus.'
            : _remarksController.text.trim(),
      );

      final updatedHistory = List<StageHistoryEntry>.from(updatedProject.stageHistory)..add(newHistoryEntry);
      updatedProject = updatedProject.copyWith(stageHistory: updatedHistory);

      // 4. Persist
      await ref.read(projectTrackerRepositoryProvider).updateProject(companyId, updatedProject, user);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Edit ${widget.departmentName} Stage'),
      content: _saving
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Container(
              width: 400,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Status
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Stage Status',
                          border: OutlineInputBorder(),
                        ),
                        items: <String>['Pending', 'In Progress', 'Completed']
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatus = val;
                              if (val == 'Completed' && _completedAt == null) {
                                _completedAt = DateTime.now();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Assignee Name
                      TextFormField(
                        controller: _assigneeController,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Employee Name',
                          hintText: 'e.g., John Doe',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Remarks
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          hintText: 'Describe details or status update reason...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_selectedStatus != widget.stage.status && (value == null || value.trim().isEmpty)) {
                            return 'Remarks are required when changing the stage status.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Completion Date (only visible when status is Completed)
                      if (_selectedStatus == 'Completed') ...[
                        InkWell(
                          onTap: () => _selectCompletionDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Completion Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(DateFormat('MMM d, yyyy').format(_completedAt ?? DateTime.now())),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      actions: [
        if (!_saving) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Stage'),
          ),
        ],
      ],
    );
  }
}
