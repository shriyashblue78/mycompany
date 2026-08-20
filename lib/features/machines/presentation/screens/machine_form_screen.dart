import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/machine_model.dart';
import '../providers/machine_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class MachineFormScreen extends ConsumerStatefulWidget {
  final String? machineId;
  final MachineModel? machine;

  const MachineFormScreen({
    super.key,
    this.machineId,
    this.machine,
  });

  @override
  ConsumerState<MachineFormScreen> createState() => _MachineFormScreenState();
}

class _MachineFormScreenState extends ConsumerState<MachineFormScreen> {
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
    _isEdit = widget.machineId != null;
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _typeController = TextEditingController();
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  void _initFields(MachineModel machine) {
    if (_initialized) return;
    _nameController.text = machine.machineName;
    _codeController.text = machine.machineCode;
    _typeController.text = machine.machineType;
    _locationController.text = machine.location;
    _descriptionController.text = machine.description;
    _selectedStatus = machine.status;
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

  Future<void> _saveForm(MachineModel? existingMachine) async {
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

      final repo = ref.read(machineRepositoryProvider);

      // 1. Validate Code Uniqueness within company
      final isUnique = await repo.isMachineCodeUnique(
        companyId,
        code,
        excludeMachineId: _isEdit ? (existingMachine?.machineId ?? widget.machineId) : null,
      );

      if (!isUnique) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Machine Code "$code" is already in use by another machine.',
            isError: true,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. Warn/Prevent Duplicate Names if possible
      final allMachines = ref.read(companyMachinesStreamProvider).value ?? [];
      final duplicateNameExists = allMachines.any((m) =>
          m.machineName.toLowerCase() == name.toLowerCase() &&
          m.machineId != (_isEdit ? (existingMachine?.machineId ?? widget.machineId) : null));

      if (duplicateNameExists) {
        // We warn the user, but we can also block it if needed. The prompt says "Prevent duplicate machine names if possible"
        // Let's block it or show a choice. For MVP security and safety, let's block it with a message.
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'A machine with the name "$name" already exists.',
            isError: true,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final machineId = _isEdit
          ? (existingMachine?.machineId ?? widget.machineId!)
          : FirebaseFirestore.instance.collection('companies').doc(companyId).collection('machines').doc().id;

      final machine = MachineModel(
        machineId: machineId,
        companyId: companyId,
        machineName: name,
        machineCode: code,
        machineType: type,
        location: location,
        status: _selectedStatus,
        description: description,
        createdAt: existingMachine?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEdit) {
        await repo.updateMachine(companyId, machine);
      } else {
        await repo.createMachine(companyId, machine);
      }

      // Trigger machine notification
      await ref.read(notificationServiceProvider).notifyMachineAddedUpdated(
        companyId: companyId,
        machineId: machine.machineId,
        machineName: machine.machineName,
        machineCode: machine.machineCode,
        status: machine.status,
        userUid: authState.user?.uid ?? '',
        userName: authState.user?.name ?? 'System',
        isEdit: _isEdit,
      );

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: _isEdit ? 'Machine updated successfully.' : 'Machine registered successfully.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error saving machine record: $e',
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
    if (_isEdit && widget.machine == null) {
      final machineAsync = ref.watch(machineDetailsStreamProvider(widget.machineId!));
      return machineAsync.when(
        data: (machine) {
          if (machine == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit Machine')),
              body: const Center(child: Text('Machine record not found.')),
            );
          }
          _initFields(machine);
          return _buildFormView(context, machine);
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      );
    }

    if (widget.machine != null) {
      _initFields(widget.machine!);
    }

    return _buildFormView(context, widget.machine);
  }

  Widget _buildFormView(BuildContext context, MachineModel? machine) {
    final theme = Theme.of(context);
    final statuses = ['Active', 'Inactive', 'Under Maintenance'];

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Machine' : 'Add Machine'),
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
                        _isEdit ? 'Update Machine Details' : 'Register New Machine',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Machine Name *',
                          prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Machine name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Machine Code *',
                          prefixIcon: Icon(Icons.qr_code_rounded),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. MCH-0001',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Machine code is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _typeController,
                        decoration: const InputDecoration(
                          labelText: 'Machine Type',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. CNC, Hydraulic, Drill',
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Production Floor 1',
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
                            onPressed: _isLoading ? null : () => _saveForm(machine),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save Machine'),
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
