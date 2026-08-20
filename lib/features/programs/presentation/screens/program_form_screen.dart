import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../machines/presentation/providers/machine_provider.dart';
import '../../../machines/domain/models/machine_model.dart';
import '../../domain/models/program_model.dart';
import '../providers/program_provider.dart';

class ProgramFormScreen extends ConsumerStatefulWidget {
  final String? programId;
  final ProgramModel? program;

  const ProgramFormScreen({
    super.key,
    this.programId,
    this.program,
  });

  @override
  ConsumerState<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends ConsumerState<ProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  String? _selectedMachineId;
  bool _isLoading = false;
  bool _isEdit = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.programId != null;
    _nameController = TextEditingController();
  }

  void _initFields(ProgramModel program) {
    if (_initialized) return;
    _nameController.text = program.programName;
    _selectedMachineId = program.machineId;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveForm(List<MachineModel> machines) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMachineId == null) {
      showFeedbackSnackBar(
        context: context,
        message: 'Please select a machine.',
        isError: true,
      );
      return;
    }

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

    final selectedMachine = machines.firstWhere((m) => m.machineId == _selectedMachineId);

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(programRepositoryProvider);

      final programId = _isEdit
          ? widget.programId!
          : FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('programs')
              .doc()
              .id;

      final program = ProgramModel(
        programId: programId,
        companyId: companyId,
        machineId: selectedMachine.machineId,
        machineName: selectedMachine.machineName,
        programName: _nameController.text.trim(),
        createdAt: _isEdit && widget.program != null ? widget.program!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEdit) {
        await repo.updateProgram(companyId, program);
      } else {
        await repo.createProgram(companyId, program);
      }

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: _isEdit 
              ? 'Program updated successfully!' 
              : 'Program "${program.programName}" registered successfully!',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to save program: $e',
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
    final theme = Theme.of(context);
    final machinesAsync = ref.watch(companyMachinesStreamProvider);

    // If edit mode and program is provided, pre-fill fields once
    if (_isEdit && widget.program != null) {
      _initFields(widget.program!);
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit CNC Program' : 'Add CNC Program'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEdit ? 'Modify CNC Program Metadata' : 'Create New CNC Machine Program',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p8),
                    Text(
                      'Link a specific numeric/code program to a machine tooling profile. Ensure the program ID matches the CNC controller index.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Machine Selector Dropdown
                    machinesAsync.when(
                      data: (machines) {
                        return DropdownButtonFormField<String>(
                          value: _selectedMachineId,
                          disabledHint: _isEdit ? Text(widget.program?.machineName ?? '') : null,
                          decoration: InputDecoration(
                            labelText: 'Select Machine *',
                            prefixIcon: const Icon(Icons.settings_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: machines.map((mch) {
                            return DropdownMenuItem<String>(
                              value: mch.machineId,
                              child: Text('${mch.machineName} (${mch.machineCode})'),
                            );
                          }).toList(),
                          onChanged: _isEdit || _isLoading 
                              ? null 
                              : (value) => setState(() => _selectedMachineId = value),
                          validator: (value) => value == null ? 'Please select a machine' : null,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error loading machines: $err', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                    const SizedBox(height: AppSizes.p20),

                    // Program Name/Number
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Program Name / Number *',
                        hintText: 'e.g., 001, 234, 5-6',
                        prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a program identifier';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.p32),

                    // Save / Cancel Buttons
                    machinesAsync.when(
                      data: (machines) => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : () => context.pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppSizes.p12),
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _saveForm(machines),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(_isEdit ? 'Save Changes' : 'Create Program', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
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
}
