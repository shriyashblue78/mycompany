import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tool_model.dart';
import '../providers/tool_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class ToolFormScreen extends ConsumerStatefulWidget {
  final String? toolId;
  final ToolModel? tool;

  const ToolFormScreen({
    super.key,
    this.toolId,
    this.tool,
  });

  @override
  ConsumerState<ToolFormScreen> createState() => _ToolFormScreenState();
}

class _ToolFormScreenState extends ConsumerState<ToolFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _typeController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  
  String _selectedStatus = 'Active';
  bool _isLoading = false;
  bool _initialized = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.toolId != null;
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _typeController = TextEditingController();
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  void _initFields(ToolModel tool) {
    if (_initialized) return;
    _nameController.text = tool.toolName;
    _codeController.text = tool.toolCode;
    _typeController.text = tool.toolType;
    _locationController.text = tool.location;
    _descriptionController.text = tool.description;
    _selectedStatus = tool.status;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _typeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveForm(ToolModel? existingTool) async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId == null || companyId.isEmpty) {
      showFeedbackSnackBar(
        context: context,
        message: 'Authentication error: Company context not found.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final code = _codeController.text.trim();
      final type = _typeController.text.trim();
      final location = _locationController.text.trim();
      final description = _descriptionController.text.trim();

      final repo = ref.read(toolRepositoryProvider);

      // 1. Validate Code Uniqueness within company
      final isUnique = await repo.isToolCodeUnique(
        companyId,
        code,
        excludeToolId: _isEdit ? (existingTool?.toolId ?? widget.toolId) : null,
      );

      if (!isUnique) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Tool Code "$code" is already in use by another tool.',
            isError: true,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. Warn/Prevent Duplicate Names if possible (mirroring Machine Master architecture)
      final allTools = ref.read(companyToolsStreamProvider).value ?? [];
      final duplicateNameExists = allTools.any((t) =>
          t.toolName.toLowerCase() == name.toLowerCase() &&
          t.toolId != (_isEdit ? (existingTool?.toolId ?? widget.toolId) : null));

      if (duplicateNameExists) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'A tool with the name "$name" already exists.',
            isError: true,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final toolId = _isEdit
          ? (existingTool?.toolId ?? widget.toolId!)
          : FirebaseFirestore.instance.collection('companies').doc(companyId).collection('tooling').doc().id;

      final tool = ToolModel(
        toolId: toolId,
        companyId: companyId,
        toolName: name,
        toolCode: code,
        toolType: type,
        location: location,
        status: _selectedStatus,
        description: description,
        createdAt: existingTool?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEdit) {
        await repo.updateTool(companyId, tool);
      } else {
        await repo.createTool(companyId, tool);
      }

      // Trigger tooling notification
      await ref.read(notificationServiceProvider).notifyToolingAddedUpdated(
        companyId: companyId,
        toolId: tool.toolId,
        toolName: tool.toolName,
        toolCode: tool.toolCode,
        status: tool.status,
        userUid: authState.user?.uid ?? '',
        userName: authState.user?.name ?? 'System',
        isEdit: _isEdit,
      );

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: _isEdit ? 'Tool updated successfully.' : 'Tool registered successfully.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error saving tool record: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && widget.tool == null) {
      final toolAsync = ref.watch(toolDetailsStreamProvider(widget.toolId!));
      return toolAsync.when(
        data: (tool) {
          if (tool == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit Tool')),
              body: const Center(child: Text('Tool record not found.')),
            );
          }
          _initFields(tool);
          return _buildFormView(context, tool);
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      );
    }

    if (widget.tool != null) {
      _initFields(widget.tool!);
    }

    return _buildFormView(context, widget.tool);
  }

  Widget _buildFormView(BuildContext context, ToolModel? tool) {
    final theme = Theme.of(context);
    final statuses = ['Active', 'Inactive'];

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Tool' : 'Add Tool'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth - 200),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Update Tool Details' : 'Register New Tool',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tool Name *',
                          prefixIcon: Icon(Icons.build_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tool name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Tool Code *',
                          prefixIcon: Icon(Icons.qr_code_rounded),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. TOL-0001',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tool code is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _typeController,
                        decoration: const InputDecoration(
                          labelText: 'Tool Type',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Hand Tool, Power Tool, Mold, Die',
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Tool Room Rack A',
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status *',
                          prefixIcon: Icon(Icons.info_outline_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Status is required';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : () => context.pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppSizes.p16),
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _saveForm(tool),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save Tool'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
