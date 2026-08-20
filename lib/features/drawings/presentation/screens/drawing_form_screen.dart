import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/drawing_model.dart';
import '../providers/drawing_provider.dart';
import '../../../../core/utils/file_picker_helper.dart';

class DrawingFormScreen extends ConsumerStatefulWidget {
  const DrawingFormScreen({super.key});

  @override
  ConsumerState<DrawingFormScreen> createState() => _DrawingFormScreenState();
}

class _DrawingFormScreenState extends ConsumerState<DrawingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _selectedFileExtension;
  int? _selectedFileSize;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePickerHelper.pickFile();

      if (file != null) {
        setState(() {
          _selectedFileBytes = file.bytes;
          _selectedFileName = file.name;
          _selectedFileExtension = file.extension;
          _selectedFileSize = file.size;

          // Auto-fill drawing name with the file name (excluding extension) if empty
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = file.name.replaceAll('.${file.extension}', '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to pick file: $e',
          isError: true,
        );
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileExtension = null;
      _selectedFileSize = null;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _uploadAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFileBytes == null) {
      showFeedbackSnackBar(
        context: context,
        message: 'Please select a PDF or image file first.',
        isError: true,
      );
      return;
    }

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    final userName = authState.userName ?? 'Unknown';

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
      final storage = ref.read(storageServiceProvider);
      final repo = ref.read(drawingRepositoryProvider);

      // 1. Generate unique drawing ID
      final drawingId = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('drawings')
          .doc()
          .id;

      // 2. Determine file type and content type
      final ext = _selectedFileExtension ?? '';
      final String fileType;
      final String contentType;

      if (ext == 'pdf') {
        fileType = 'pdf';
        contentType = 'application/pdf';
      } else {
        fileType = 'image';
        contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      }

      // 3. Define Storage path: companies/{companyId}/drawings/{drawingId}_{fileName}
      final sanitizedFileName = _selectedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final storagePath = 'companies/$companyId/drawings/${drawingId}_$sanitizedFileName';

      // 4. Upload bytes to Firebase Storage
      final downloadUrl = await storage.uploadBytes(
        path: storagePath,
        bytes: _selectedFileBytes!,
        contentType: contentType,
      );

      // 5. Build and save DrawingModel metadata to Firestore
      final drawing = DrawingModel(
        drawingId: drawingId,
        companyId: companyId,
        drawingName: _nameController.text.trim(),
        fileUrl: downloadUrl,
        fileType: fileType,
        uploadedBy: userName,
        storagePath: storagePath,
        createdAt: DateTime.now(),
      );

      await repo.createDrawing(companyId, drawing);

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Drawing "${drawing.drawingName}" successfully uploaded!',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Upload failed: $e',
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
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Upload Design Drawing'),
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
                      'Upload Company Drawing / CAD / Schematics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p8),
                    Text(
                      'Owner and HR roles can upload engineering schematics, product designs, or assembly templates in PDF or Image format (PNG, JPG, JPEG).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // File picker area
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _selectedFileBytes != null 
                              ? theme.colorScheme.primary.withOpacity(0.5)
                              : theme.dividerColor.withAlpha(40),
                          width: _selectedFileBytes != null ? 1.5 : 1,
                        ),
                      ),
                      color: isDark 
                          ? theme.colorScheme.surface 
                          : Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p20),
                        child: Column(
                          children: [
                            if (_selectedFileBytes == null) ...[
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: theme.colorScheme.primary.withOpacity(0.7),
                              ),
                              const SizedBox(height: AppSizes.p12),
                              const Text(
                                'Select Design File',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Accepted formats: PDF, PNG, JPG, JPEG (Max 10MB)',
                                style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: AppSizes.p16),
                              ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.file_present_rounded, size: 18),
                                label: const Text('Browse Files'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (_selectedFileExtension == 'pdf' 
                                          ? Colors.red.shade50 
                                          : theme.colorScheme.primary.withAlpha(20)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _selectedFileExtension == 'pdf'
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.image_rounded,
                                      color: _selectedFileExtension == 'pdf'
                                          ? Colors.red.shade700
                                          : theme.colorScheme.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFileName ?? 'File Selected',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatFileSize(_selectedFileSize ?? 0),
                                          style: TextStyle(
                                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _clearFile,
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                    tooltip: 'Remove selected file',
                                  ),
                                ],
                              ),

                              // Preview for picked Image files
                              if (_selectedFileExtension != 'pdf' && _selectedFileBytes != null) ...[
                                const SizedBox(height: AppSizes.p16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: theme.dividerColor.withAlpha(20)),
                                    ),
                                    child: Image.memory(
                                      _selectedFileBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Drawing Name Field
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Drawing / Design Name *',
                        hintText: 'e.g., Gear Assembly Schematic V2',
                        prefixIcon: const Icon(Icons.title_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a drawing name';
                        }
                        if (value.trim().length < 3) {
                          return 'Drawing name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.p32),

                    // Action buttons
                    Row(
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
                          onPressed: _isLoading ? null : _uploadAndSave,
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
                              : const Text('Upload Drawing', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}
