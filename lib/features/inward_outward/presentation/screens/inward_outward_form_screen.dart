import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/inward_outward_repository_impl.dart';
import '../../domain/models/inward_outward_model.dart';

class InwardOutwardPhotoItem {
  final Uint8List bytes;
  final String mimeType;
  final String name;

  InwardOutwardPhotoItem({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });
}

class InwardOutwardFormScreen extends ConsumerStatefulWidget {
  const InwardOutwardFormScreen({super.key});

  @override
  ConsumerState<InwardOutwardFormScreen> createState() => _InwardOutwardFormScreenState();
}

class _InwardOutwardFormScreenState extends ConsumerState<InwardOutwardFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String _direction = 'Inward';
  final _companyNameController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _partNameController = TextEditingController();
  final _challanNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  String _quantityUnit = 'Numbers/Pieces';
  DateTime _selectedDate = DateTime.now();

  final List<InwardOutwardPhotoItem> _challanPhotos = [];
  final List<InwardOutwardPhotoItem> _materialPhotos = [];

  bool _isSubmitting = false;

  final List<String> _unitOptions = [
    'Numbers/Pieces',
    'Kilograms (kg)',
    'Tons',
  ];

  @override
  void dispose() {
    _companyNameController.dispose();
    _partNumberController.dispose();
    _partNameController.dispose();
    _challanNumberController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickChallanPhotosFromGallery() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (images.isEmpty) return;

      final newItems = <InwardOutwardPhotoItem>[];
      for (final img in images) {
        final bytes = await img.readAsBytes();
        newItems.add(InwardOutwardPhotoItem(
          bytes: bytes,
          mimeType: img.mimeType ?? 'image/jpeg',
          name: img.name,
        ));
      }

      setState(() {
        _challanPhotos.addAll(newItems);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick challan photos: $e')),
        );
      }
    }
  }

  Future<void> _pickChallanPhotoFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _challanPhotos.add(InwardOutwardPhotoItem(
          bytes: bytes,
          mimeType: image.mimeType ?? 'image/jpeg',
          name: image.name,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture challan photo: $e')),
        );
      }
    }
  }

  void _showChallanSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickChallanPhotoFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose Multiple from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickChallanPhotosFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMaterialPhotos() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (images.isEmpty) return;

      final newItems = <InwardOutwardPhotoItem>[];
      for (final img in images) {
        final bytes = await img.readAsBytes();
        newItems.add(InwardOutwardPhotoItem(
          bytes: bytes,
          mimeType: img.mimeType ?? 'image/jpeg',
          name: img.name,
        ));
      }

      setState(() {
        _materialPhotos.addAll(newItems);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick material photos: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final user = authState.user;
    final companyId = user?.companyId ?? '';

    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company profile missing. Please log in again.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final storageService = ref.read(storageServiceProvider);
      final recordId = 'rec_${DateTime.now().millisecondsSinceEpoch}';

      final challanUrls = <String>[];
      for (int i = 0; i < _challanPhotos.length; i++) {
        final item = _challanPhotos[i];
        final path = 'companies/$companyId/inward_outward/$recordId/challan_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await storageService.uploadBytes(
          path: path,
          bytes: item.bytes,
          contentType: item.mimeType,
        );
        challanUrls.add(url);
      }

      final materialUrls = <String>[];
      for (int i = 0; i < _materialPhotos.length; i++) {
        final item = _materialPhotos[i];
        final path = 'companies/$companyId/inward_outward/$recordId/material_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await storageService.uploadBytes(
          path: path,
          bytes: item.bytes,
          contentType: item.mimeType,
        );
        materialUrls.add(url);
      }

      final record = InwardOutwardModel(
        id: recordId,
        companyId: companyId,
        direction: _direction,
        companyName: _companyNameController.text.trim(),
        partNumber: _partNumberController.text.trim(),
        partName: _partNameController.text.trim(),
        challanNumber: _challanNumberController.text.trim(),
        date: _selectedDate,
        quantity: double.parse(_quantityController.text.trim()),
        quantityUnit: _quantityUnit,
        challanPhotoUrls: challanUrls,
        materialPhotoUrls: materialUrls,
        createdAt: DateTime.now(),
        createdByUid: user?.uid ?? '',
        createdByName: user?.name ?? 'System User',
      );

      await ref.read(inwardOutwardRepositoryProvider).addRecord(companyId, record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_direction entry logged successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Log Inward / Outward Entry'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entry Type & Basic Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Direction Selector
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.p8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Inward',
                          label: Text('INWARD'),
                          icon: Icon(Icons.south_west_rounded),
                        ),
                        ButtonSegment(
                          value: 'Outward',
                          label: Text('OUTWARD'),
                          icon: Icon(Icons.north_east_rounded),
                        ),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _direction = selection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSizes.p20),

                  // Company Name & Date
                  if (isMobile) ...[
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Party Name *',
                        hintText: 'e.g. Apex Suppliers Ltd.',
                        prefixIcon: Icon(Icons.business_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Company name is required' : null,
                    ),
                    const SizedBox(height: AppSizes.p16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Challan Date *',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _companyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Company / Party Name *',
                              hintText: 'e.g. Apex Suppliers Ltd.',
                              prefixIcon: Icon(Icons.business_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Company name is required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Challan Date *',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSizes.p16),

                  // Part Number & Part Name
                  if (isMobile) ...[
                    TextFormField(
                      controller: _partNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Part Number *',
                        hintText: 'e.g. PN-9942',
                        prefixIcon: Icon(Icons.tag_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Part number is required' : null,
                    ),
                    const SizedBox(height: AppSizes.p16),
                    TextFormField(
                      controller: _partNameController,
                      decoration: const InputDecoration(
                        labelText: 'Part Name *',
                        hintText: 'e.g. Steel Flange Bracket',
                        prefixIcon: Icon(Icons.build_circle_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Part name is required' : null,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _partNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Part Number *',
                              hintText: 'e.g. PN-9942',
                              prefixIcon: Icon(Icons.tag_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Part number is required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: TextFormField(
                            controller: _partNameController,
                            decoration: const InputDecoration(
                              labelText: 'Part Name *',
                              hintText: 'e.g. Steel Flange Bracket',
                              prefixIcon: Icon(Icons.build_circle_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Part name is required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSizes.p16),

                  // Challan Number, Quantity & Unit
                  if (isMobile) ...[
                    TextFormField(
                      controller: _challanNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Challan Number *',
                        hintText: 'e.g. CH-2026-081',
                        prefixIcon: Icon(Icons.receipt_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Challan number is required' : null,
                    ),
                    const SizedBox(height: AppSizes.p16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.numbers_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              if (double.tryParse(val.trim()) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _quantityUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit *',
                              border: OutlineInputBorder(),
                            ),
                            items: _unitOptions.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _quantityUnit = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _challanNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Challan Number *',
                              hintText: 'e.g. CH-2026-081',
                              prefixIcon: Icon(Icons.receipt_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Challan number is required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.numbers_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              if (double.tryParse(val.trim()) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _quantityUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit *',
                              border: OutlineInputBorder(),
                            ),
                            items: _unitOptions.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _quantityUnit = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSizes.p24),

                  const Divider(),
                  const SizedBox(height: AppSizes.p16),

                  // Photo Upload Section
                  Text(
                    'Photo Documentation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p8),
                  Text(
                    'Attach Challan document photo and material inspection photos for company records.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Challan Photos
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Challan Photos (${_challanPhotos.length} attached)',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Attach official challan document photos',
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.hintColor),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _showChallanSourcePicker,
                                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                                label: Text(isMobile ? 'Add Challan' : 'Add Challan Photos'),
                              ),
                            ],
                          ),
                          if (_challanPhotos.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.p12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isMobile ? 2 : 4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _challanPhotos.length,
                              itemBuilder: (ctx, index) {
                                final photo = _challanPhotos[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        photo.bytes,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.black.withOpacity(0.7),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          iconSize: 16,
                                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                                          onPressed: () {
                                            setState(() {
                                              _challanPhotos.removeAt(index);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Material Photos
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Material Photos (${_materialPhotos.length} attached)',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Attach at least 2 material inspection photos',
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.hintColor),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _pickMaterialPhotos,
                                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                label: Text(isMobile ? 'Add Material' : 'Add Material Photos'),
                              ),
                            ],
                          ),
                          if (_materialPhotos.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.p12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isMobile ? 2 : 4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _materialPhotos.length,
                              itemBuilder: (ctx, index) {
                                final photo = _materialPhotos[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        photo.bytes,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.black.withOpacity(0.7),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          iconSize: 16,
                                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                                          onPressed: () {
                                            setState(() {
                                              _materialPhotos.removeAt(index);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _direction == 'Inward' ? AppColors.success : AppColors.info,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSubmitting ? 'Saving Entry...' : 'Save $_direction Entry',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
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
