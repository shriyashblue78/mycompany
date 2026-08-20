import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/storage_service.dart';
import '../../../machines/presentation/providers/machine_provider.dart';
import '../../../machines/domain/models/machine_model.dart';
import '../../domain/models/task_model.dart';
import '../providers/tasks_provider.dart';
import '../../../programs/domain/models/program_model.dart';
import '../../../programs/presentation/providers/program_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId;
  final TaskModel? task;
  const TaskFormScreen({super.key, this.taskId, this.task});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedEmployeeId;
  String? _selectedDepartment;
  String? _selectedMachineId;
  String? _selectedProgramId;
  String _selectedPriority = 'Medium';
  String _selectedStatus = 'Pending Acceptance'; // Default for new tasks

  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  Uint8List? _drawingPhotoBytes;
  String? _drawingPhotoUrl;
  String? _photoContentType;

  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeValues(TaskModel? task) {
    if (_initialized) return;
    if (task != null) {
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _selectedEmployeeId = task.assignedToEmployeeId;
      _selectedDepartment = task.department;
      _selectedMachineId = task.machineId;
      _selectedProgramId = task.programId;
      _selectedPriority = task.priority;
      _selectedStatus = task.status;
      _startDate = task.startDate;
      _dueDate = task.dueDate;
      _drawingPhotoUrl = task.drawingPhotoUrl;
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.taskId != null;

    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    // Initialize values if editing
    if (isEditing) {
      _initializeValues(widget.task);
    }

    final employeesAsync = ref.watch(companyEmployeesProvider);
    final machinesAsync = ref.watch(companyMachinesStreamProvider);
    final programsAsync = ref.watch(companyProgramsStreamProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task Specifications' : 'Delegate New Task'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Modify Job specifications and attributes' : 'Define and delegate operational deliverable details.',
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Title Input
                          _buildLabel('Task Title *'),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'Enter title...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Description Input
                          _buildLabel('Description / Specifications *'),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Provide detailed job outline...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Description is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Row of Department and Assignee Selection
                          // Department and Assignee Selection
                          ResponsiveFormRow(
                            children: [
                              _buildDepartmentField(),
                              _buildAssigneeField(employeesAsync),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p16),

                          ResponsiveFormRow(
                            children: [
                               _buildMachineField(machinesAsync, programsAsync),
                              _buildPhotoField(),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Priority and Status
                          ResponsiveFormRow(
                            children: [
                              _buildPriorityField(),
                              _buildStatusField(),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Date Selectors
                          ResponsiveFormRow(
                            children: [
                              _buildStartDateField(context),
                              _buildDueDateField(context),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => _submitForm(user, employeesAsync, machinesAsync),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                ),
                              ),
                              child: Text(
                                isEditing ? 'Save Changes' : 'Delegate and Dispatch Task',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  void _pickStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        if (_dueDate.isBefore(_startDate)) {
          _dueDate = _startDate.add(const Duration(days: 7));
        }
      });
    }
  }

  void _pickDueDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _drawingPhotoBytes = bytes;
          _photoContentType = image.mimeType ?? 'image/jpeg';
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _submitForm(
    dynamic currentUser,
    AsyncValue<List<EmployeeModel>> employeesAsync,
    AsyncValue<List<MachineModel>> machinesAsync,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    final employees = employeesAsync.value;
    if (employees == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff directory not ready. Please try again.')),
      );
      return;
    }

    final assignee = employees.firstWhere((e) => e.employeeId == _selectedEmployeeId);

    // Retrieve machine details if a machine was selected
    MachineModel? selectedMachine;
    if (_selectedMachineId != null && machinesAsync.value != null) {
      selectedMachine = machinesAsync.value!.where((m) => m.machineId == _selectedMachineId).firstOrNull;
    }

    final programsAsync = ref.read(companyProgramsStreamProvider);
    ProgramModel? selectedProgram;
    if (_selectedProgramId != null && programsAsync.value != null) {
      selectedProgram = programsAsync.value!.where((p) => p.programId == _selectedProgramId).firstOrNull;
    }

    setState(() => _loading = true);

    try {
      final companyId = currentUser.companyId;
      final assignedByName = currentUser.name ?? 'Manager';

      String? uploadedPhotoUrl = _drawingPhotoUrl;
      if (_drawingPhotoBytes != null) {
        final storage = StorageService();
        final path = 'companies/$companyId/tasks/photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedPhotoUrl = await storage.uploadBytes(
          path: path,
          bytes: _drawingPhotoBytes!,
          contentType: _photoContentType ?? 'image/jpeg',
        );
      }

      if (widget.taskId == null) {
        // Create new task
        final newTaskId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('tasks').doc().id;
        final newTask = TaskModel(
          taskId: newTaskId,
          companyId: companyId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          assignedToEmployeeId: assignee.employeeId,
          assignedToUid: assignee.uid,
          assignedToName: assignee.name,
          assignedBy: assignedByName,
          priority: _selectedPriority,
          status: 'Pending Acceptance', // Override default if needed
          department: _selectedDepartment!,
          machineId: selectedMachine?.machineId,
          machineName: selectedMachine?.machineName,
          machineCode: selectedMachine?.machineCode,
          programId: selectedProgram?.programId,
          programName: selectedProgram?.programName,
          drawingPhotoUrl: uploadedPhotoUrl,
          startDate: _startDate,
          dueDate: _dueDate,
          progress: 0.0,
          attachments: [],
          remarks: ['Task created & delegated to ${assignee.name} by $assignedByName.'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await ref.read(taskRepositoryProvider).createTask(companyId, newTask);
        await TaskNotificationService.notifyNewTaskAssigned(ref, newTask, companyId, assignedByName);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created & assigned successfully!')),
        );
      } else {
        // Edit existing task
        final existingTask = widget.task!;
        
        // If re-assigned to a new employee, reset rejection status
        final isReassigned = existingTask.assignedToUid != assignee.uid;
        final String newStatus = isReassigned ? 'Pending Acceptance' : _selectedStatus;

        final updatedTask = existingTask.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          assignedToEmployeeId: assignee.employeeId,
          assignedToUid: assignee.uid,
          assignedToName: assignee.name,
          assignedBy: assignedByName,
          priority: _selectedPriority,
          status: newStatus,
          department: _selectedDepartment!,
          machineId: selectedMachine?.machineId,
          machineName: selectedMachine?.machineName,
          machineCode: selectedMachine?.machineCode,
          programId: selectedProgram?.programId,
          programName: selectedProgram?.programName,
          drawingPhotoUrl: uploadedPhotoUrl,
          startDate: _startDate,
          dueDate: _dueDate,
          rejectedByUid: isReassigned ? null : existingTask.rejectedByUid,
          rejectedByName: isReassigned ? null : existingTask.rejectedByName,
          rejectedAt: isReassigned ? null : existingTask.rejectedAt,
          rejectionReason: isReassigned ? null : existingTask.rejectionReason,
          progress: newStatus == 'Completed' ? 100.0 : existingTask.progress,
          completedDate: newStatus == 'Completed'
              ? (existingTask.completedDate ?? DateTime.now())
              : (newStatus == 'Cancelled' ? existingTask.completedDate : null),
          remarks: [
            ...existingTask.remarks,
            'Task specifications updated by $assignedByName on ${DateTime.now().toString().substring(0, 16)}.'
          ],
        );

        await ref.read(taskRepositoryProvider).updateTask(companyId, updatedTask);
        if (isReassigned) {
          await TaskNotificationService.notifyNewTaskAssigned(ref, updatedTask, companyId, assignedByName);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task specs updated successfully!')),
        );
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save task specifications: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Widget _buildDepartmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Department *'),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          hint: const Text('Select Dept'),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: kDepartments.map((dept) {
            return DropdownMenuItem(value: dept, child: Text(dept));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedDepartment = val;
            });
          },
          validator: (val) => val == null ? 'Department is required' : null,
        ),
      ],
    );
  }

  Widget _buildAssigneeField(AsyncValue<List<EmployeeModel>> employeesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Assignee *'),
        employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error loading staff: $err'),
          data: (list) {
            return DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedEmployeeId,
              hint: const Text('Select Employee'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: list.map((emp) {
                return DropdownMenuItem(
                  value: emp.employeeId,
                  child: Text(
                    '${emp.name} (${emp.role})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedEmployeeId = val;
                });
              },
              validator: (val) => val == null ? 'Assignee is required' : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildPriorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Priority *'),
        DropdownButtonFormField<String>(
          value: _selectedPriority,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: kTaskPriorities.map((p) {
            return DropdownMenuItem(value: p, child: Text(p));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedPriority = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Status *'),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: kTaskStatuses.map((s) {
            return DropdownMenuItem(value: s, child: Text(s));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedStatus = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildStartDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Start Date *'),
        OutlinedButton.icon(
          onPressed: () => _pickStartDate(context),
          icon: const Icon(Icons.calendar_today),
          label: Text(
            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Due Date *'),
        OutlinedButton.icon(
          onPressed: () => _pickDueDate(context),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMachineField(
    AsyncValue<List<MachineModel>> machinesAsync,
    AsyncValue<List<ProgramModel>> programsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Machine (Optional)'),
        machinesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error loading machines: $err'),
          data: (list) {
            return DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedMachineId,
              hint: const Text('Select Machine'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None'),
                ),
                ...list.map((mch) {
                  return DropdownMenuItem(
                    value: mch.machineId,
                    child: Text(
                      '${mch.machineName} (${mch.machineCode})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedMachineId = val;
                  _selectedProgramId = null; // Clear selected program when machine changes
                });
              },
            );
          },
        ),
        if (_selectedMachineId != null) ...[
          const SizedBox(height: AppSizes.p12),
          _buildLabel('Program (Optional)'),
          programsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error loading programs: $err'),
            data: (programsList) {
              final machinePrograms = programsList.where((p) => p.machineId == _selectedMachineId).toList();
              if (machinePrograms.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text(
                    'No programs registered for this machine.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                );
              }
              return DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedProgramId,
                hint: const Text('Select Program'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...machinePrograms.map((prog) {
                    return DropdownMenuItem(
                      value: prog.programId,
                      child: Text(
                        'Program ${prog.programName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedProgramId = val;
                  });
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoField() {
    final hasPhoto = _drawingPhotoBytes != null || _drawingPhotoUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Drawing/Task Photo'),
        GestureDetector(
          onTap: _pickImage,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
            ),
            child: Row(
              children: [
                Icon(
                  hasPhoto ? Icons.check_circle : Icons.camera_alt_outlined,
                  color: hasPhoto ? Colors.green : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPhoto ? 'Photo selected/attached' : 'Tap to attach photo',
                    style: TextStyle(color: hasPhoto ? Colors.green.shade700 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
