import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/file_picker_helper.dart';
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

  // Existing uploaded URLs
  List<String> _existingImageUrls = [];
  List<String> _existingPdfUrls = [];

  // Newly picked local files waiting to upload
  final List<PickedFileResult> _newImages = [];
  final List<PickedFileResult> _newPdfs = [];

  final StorageService _storageService = StorageService();

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
    _existingImageUrls = List<String>.from(program.imageUrls);
    _existingPdfUrls = List<String>.from(program.pdfUrls);
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final results = await FilePickerHelper.pickMultipleFiles(
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (results.isNotEmpty) {
        setState(() {
          _newImages.addAll(results);
        });
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error picking images: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickPdfs() async {
    try {
      final results = await FilePickerHelper.pickMultipleFiles(
        allowedExtensions: ['pdf'],
      );
      if (results.isNotEmpty) {
        setState(() {
          _newPdfs.addAll(results);
        });
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error picking PDFs: $e',
          isError: true,
        );
      }
    }
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

      // Upload newly picked images
      final finalImageUrls = List<String>.from(_existingImageUrls);
      for (int i = 0; i < _newImages.length; i++) {
        final img = _newImages[i];
        final ext = img.extension.isNotEmpty ? img.extension : 'jpg';
        final path = 'companies/$companyId/programs/$programId/images/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final url = await _storageService.uploadBytes(
          path: path,
          bytes: img.bytes,
          contentType: contentType,
        );
        finalImageUrls.add(url);
      }

      // Upload newly picked PDFs
      final finalPdfUrls = List<String>.from(_existingPdfUrls);
      for (int i = 0; i < _newPdfs.length; i++) {
        final pdf = _newPdfs[i];
        final path = 'companies/$companyId/programs/$programId/pdfs/${DateTime.now().millisecondsSinceEpoch}_$i.pdf';
        final url = await _storageService.uploadBytes(
          path: path,
          bytes: pdf.bytes,
          contentType: 'application/pdf',
        );
        finalPdfUrls.add(url);
      }

      final program = ProgramModel(
        programId: programId,
        companyId: companyId,
        machineId: selectedMachine.machineId,
        machineName: selectedMachine.machineName,
        programName: _nameController.text.trim(),
        imageUrls: finalImageUrls,
        pdfUrls: finalPdfUrls,
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
              constraints: const BoxConstraints(maxWidth: 680),
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
                    const SizedBox(height: AppSizes.p24),

                    // --- SECTION: OPTIONAL IMAGES ---
                    _buildAttachmentSection(
                      title: 'Program Images (Optional)',
                      subtitle: 'Add screenshots, setup photos, or tooling images for operator reference.',
                      icon: Icons.image_outlined,
                      buttonLabel: 'Add Images',
                      onAdd: _isLoading ? null : _pickImages,
                      existingCount: _existingImageUrls.length,
                      newCount: _newImages.length,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_existingImageUrls.isNotEmpty) ...[
                            const Text('Existing Images:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _existingImageUrls.map((url) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: _isLoading ? null : () => setState(() => _existingImageUrls.remove(url)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_newImages.isNotEmpty) ...[
                            const Text('Newly Selected Images:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _newImages.map((img) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        img.bytes,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: _isLoading ? null : () => setState(() => _newImages.remove(img)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                      theme: theme,
                    ),
                    const SizedBox(height: AppSizes.p20),

                    // --- SECTION: OPTIONAL PDFS ---
                    _buildAttachmentSection(
                      title: 'Program PDFs / Documentation (Optional)',
                      subtitle: 'Attach G-code sheets, setup guides, tool offset lists, or drawing PDFs.',
                      icon: Icons.picture_as_pdf_outlined,
                      buttonLabel: 'Add PDFs',
                      onAdd: _isLoading ? null : _pickPdfs,
                      existingCount: _existingPdfUrls.length,
                      newCount: _newPdfs.length,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_existingPdfUrls.isNotEmpty) ...[
                            const Text('Existing Documents:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            ..._existingPdfUrls.map((url) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Uploaded PDF Document',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                      onPressed: () async {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      onPressed: _isLoading ? null : () => setState(() => _existingPdfUrls.remove(url)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          if (_newPdfs.isNotEmpty) ...[
                            const Text('Newly Selected PDFs:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            ..._newPdfs.map((pdf) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        pdf.name,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${(pdf.size / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                      onPressed: _isLoading ? null : () => setState(() => _newPdfs.remove(pdf)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                      theme: theme,
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

  Widget _buildAttachmentSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonLabel,
    required VoidCallback? onAdd,
    required int existingCount,
    required int newCount,
    required Widget content,
    required ThemeData theme,
  }) {
    final hasAttachments = (existingCount + newCount) > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (hasAttachments) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            content,
          ],
        ],
      ),
    );
  }
}
