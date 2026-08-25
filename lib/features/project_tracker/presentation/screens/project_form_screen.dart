import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/project_model.dart';
import '../providers/project_tracker_provider.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final String? projectId;
  final ProjectModel? project;

  const ProjectFormScreen({
    super.key,
    this.projectId,
    this.project,
  });

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String _selectedStatus = 'Planned';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool _isLoading = false;
  bool _isEditMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.projectId != null;

    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    if (_isEditMode && widget.project != null) {
      _nameController.text = widget.project!.projectName;
      _descriptionController.text = widget.project!.description;
      _selectedStatus = widget.project!.status;
      _startDate = widget.project!.startDate;
      _endDate = widget.project!.endDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _saveForm() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    final user = authState.user;
    final repository = ref.read(projectTrackerRepositoryProvider);

    if (companyId == null || user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unauthorized context. No user found.';
      });
      return;
    }

    try {
      if (_isEditMode) {
        final existingProj = widget.project;
        if (existingProj == null) throw Exception('Project data is missing.');

        final updatedProject = existingProj.copyWith(
          projectName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
          updatedAt: DateTime.now(),
        );

        await repository.updateProject(companyId, updatedProject, user);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project updated successfully.'), backgroundColor: Colors.green),
          );
          context.pop();
        }
      } else {
        final newProjectId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('projects').doc().id;

        final newProject = ProjectModel(
          projectId: newProjectId,
          companyId: companyId,
          projectName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createProject(companyId, newProject, user);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project created successfully.'), backgroundColor: Colors.green),
          );
          context.pop();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Project' : 'Create New Project'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                padding: const EdgeInsets.all(AppSizes.p24),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Project Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Project Name *',
                            prefixIcon: const Icon(Icons.folder_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Project name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Project Description *',
                            prefixIcon: const Icon(Icons.description_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Project description is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Status Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            prefixIcon: const Icon(Icons.info_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: <String>['Planned', 'In Progress', 'Completed', 'On Hold']
                              .map((status) => DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatus = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date Pickers
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectStartDate(context),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Start Date *',
                                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectEndDate(context),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'End Date (Optional)',
                                    prefixIcon: const Icon(Icons.calendar_month_rounded),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'Not Set'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  _isEditMode ? 'Save Changes' : 'Create Project',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
