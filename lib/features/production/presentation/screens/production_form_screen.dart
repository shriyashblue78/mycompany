import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../domain/models/production_model.dart';
import '../providers/production_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

// New imports for tooling and drawings
import '../../../tooling/domain/models/tool_model.dart';
import '../../../tooling/presentation/providers/tool_provider.dart';
import '../../../../core/utils/file_picker_helper.dart';

class ProductionFormScreen extends ConsumerStatefulWidget {
  final String? productionId;
  final ProductionModel? production;

  const ProductionFormScreen({
    super.key,
    this.productionId,
    this.production,
  });

  @override
  ConsumerState<ProductionFormScreen> createState() => _ProductionFormScreenState();
}

class _ProductionFormScreenState extends ConsumerState<ProductionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _productNameController;
  late TextEditingController _targetQtyController;
  late TextEditingController _completedQtyController;
  late TextEditingController _rejectedQtyController;
  late TextEditingController _remarksController;

  // Selected values
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'Pending';
  String? _selectedSupervisorId;
  final List<String> _selectedEmployeeIds = [];

  // New selected values for tooling and drawings
  final List<String> _selectedToolIds = [];
  final List<String> _selectedToolNames = [];
  String? _drawingUrl;
  String? _drawingFileName;

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _selectedFileExtension;

  bool _isEdit = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.productionId != null || widget.production != null;

    _productNameController = TextEditingController();
    _targetQtyController = TextEditingController();
    _completedQtyController = TextEditingController(text: '0');
    _rejectedQtyController = TextEditingController(text: '0');
    _remarksController = TextEditingController();

    if (_isEdit) {
      final prod = widget.production;
      if (prod != null) {
        _populateFields(prod);
      } else if (widget.productionId != null) {
        // If passed only ID, fields will be populated once stream fires.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchAndPopulate();
        });
      }
    }
  }

  void _populateFields(ProductionModel prod) {
    _productNameController.text = prod.productName;
    _targetQtyController.text = prod.quantity.toString();
    _completedQtyController.text = prod.completedQuantity.toString();
    _rejectedQtyController.text = prod.rejectedQuantity.toString();
    _remarksController.text = prod.remarks;
    _selectedDate = prod.productionDate;
    _selectedStatus = prod.status;
    _selectedSupervisorId = prod.assignedSupervisor;
    _selectedEmployeeIds.clear();
    _selectedEmployeeIds.addAll(prod.assignedEmployees);

    // Populate new fields
    _selectedToolIds.clear();
    _selectedToolIds.addAll(prod.selectedToolIds ?? []);
    _selectedToolNames.clear();
    _selectedToolNames.addAll(prod.selectedToolNames ?? []);
    _drawingUrl = prod.drawingUrl;
    _drawingFileName = prod.drawingFileName;
  }

  Future<void> _fetchAndPopulate() async {
    setState(() => _isLoading = true);
    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId != null && widget.productionId != null) {
      final repo = ref.read(productionRepositoryProvider);
      final stream = repo.streamProductionById(companyId, widget.productionId!);
      final prod = await stream.first;
      if (prod != null && mounted) {
        _populateFields(prod);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _targetQtyController.dispose();
    _completedQtyController.dispose();
    _rejectedQtyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // Calculate remaining dynamically
  int _calculateRemaining() {
    final target = int.tryParse(_targetQtyController.text) ?? 0;
    final completed = int.tryParse(_completedQtyController.text) ?? 0;
    final rejected = int.tryParse(_rejectedQtyController.text) ?? 0;
    return (target - completed - rejected).clamp(0, target);
  }

  // Handle auto status complete when completed quantity meets or exceeds target
  void _onCompletedQtyChanged(String val) {
    final completed = int.tryParse(val) ?? 0;
    final target = int.tryParse(_targetQtyController.text) ?? 0;
    if (completed >= target && target > 0) {
      setState(() {
        _selectedStatus = 'Completed';
      });
    }
    setState(() {}); // refresh remaining qty UI
  }

  // Handle changes to target qty to recalculate status and remaining qty
  void _onTargetQtyChanged(String val) {
    final target = int.tryParse(val) ?? 0;
    final completed = int.tryParse(_completedQtyController.text) ?? 0;
    if (completed >= target && target > 0) {
      setState(() {
        _selectedStatus = 'Completed';
      });
    }
    setState(() {}); // refresh remaining qty UI
  }

  // Refresh remaining qty UI when rejected quantity changes
  void _onRejectedQtyChanged(String val) {
    setState(() {}); // refresh remaining qty UI
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePickerHelper.pickFile();
      if (file != null) {
        setState(() {
          _selectedFileBytes = file.bytes;
          _selectedFileName = file.name;
          _selectedFileExtension = file.extension;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileExtension = null;
    });
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Company authentication context not found.')),
      );
      return;
    }

    if (_selectedSupervisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assigned supervisor.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final targetQty = int.parse(_targetQtyController.text);
      final completedQty = _isEdit ? int.parse(_completedQtyController.text) : 0;
      final rejectedQty = _isEdit ? int.parse(_rejectedQtyController.text) : 0;
      final productionId = _isEdit
          ? (widget.production?.productionId ?? widget.productionId!)
          : FirebaseFirestore.instance.collection('companies').doc(companyId).collection('production').doc().id;

      // Handle file upload
      String? uploadedUrl = _drawingUrl;
      String? uploadedFileName = _drawingFileName;

      if (_selectedFileBytes != null && _selectedFileName != null) {
        final storage = ref.read(storageServiceProvider);
        final ext = _selectedFileExtension ?? 'jpg';
        final contentType = ext == 'pdf'
            ? 'application/pdf'
            : (ext == 'png' ? 'image/png' : 'image/jpeg');
        final sanitizedName = _selectedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
        final path = 'companies/$companyId/production/drawings/${productionId}_$sanitizedName';

        uploadedUrl = await storage.uploadBytes(
          path: path,
          bytes: _selectedFileBytes!,
          contentType: contentType,
        );
        uploadedFileName = _selectedFileName;
      }

      final production = ProductionModel(
        productionId: productionId,
        productName: _productNameController.text.trim(),
        quantity: targetQty,
        completedQuantity: completedQty,
        rejectedQuantity: rejectedQty,
        assignedSupervisor: _selectedSupervisorId!,
        assignedEmployees: _selectedEmployeeIds,
        productionDate: _selectedDate,
        status: _selectedStatus,
        remarks: _remarksController.text.trim(),
        createdAt: widget.production?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        selectedToolIds: _selectedToolIds,
        selectedToolNames: _selectedToolNames,
        drawingUrl: uploadedUrl,
        drawingFileName: uploadedFileName,
      );

      final repo = ref.read(productionRepositoryProvider);
      if (_isEdit) {
        await repo.updateProduction(companyId, production);
      } else {
        await repo.createProduction(companyId, production);
      }

      // Trigger production notification
      await ref.read(notificationServiceProvider).notifyProductionAddedUpdatedCompleted(
        companyId: companyId,
        productionId: production.productionId,
        productName: production.productName,
        quantity: production.quantity.toDouble(),
        status: production.status,
        userUid: authState.user?.uid ?? '',
        userName: authState.user?.name ?? 'System',
        isEdit: _isEdit,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Production record updated successfully.' : 'Production record created successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving record: $e')),
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
    final employeesAsync = ref.watch(productionEmployeesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Production' : 'Create Production'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      TextFormField(
                        controller: _productNameController,
                        decoration: InputDecoration(
                          labelText: 'Product Name',
                          hintText: 'e.g. Steel Pipe, Plastic Bottle',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                          ),
                          prefixIcon: const Icon(Icons.precision_manufacturing_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter product name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Target Quantity
                      TextFormField(
                        controller: _targetQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Target Quantity',
                          hintText: 'e.g. 1000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                          ),
                          prefixIcon: const Icon(Icons.shopping_bag_outlined),
                        ),
                        onChanged: _onTargetQtyChanged,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter target quantity';
                          }
                          final parsed = int.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Quantity must be a positive integer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Completed and Rejected Quantities (Only shown on edit/update screen)
                      if (_isEdit) ...[
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _completedQtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Completed Qty',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                                prefixIcon: const Icon(Icons.done_all_rounded, color: Colors.green),
                              ),
                              onChanged: _onCompletedQtyChanged,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final parsed = int.tryParse(value);
                                if (parsed == null || parsed < 0) {
                                  return 'Must be >= 0';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _rejectedQtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Rejected Qty',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                                prefixIcon: const Icon(Icons.cancel_outlined, color: Colors.red),
                              ),
                              onChanged: _onRejectedQtyChanged,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final parsed = int.tryParse(value);
                                if (parsed == null || parsed < 0) {
                                  return 'Must be >= 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Dynamic Remaining Display Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Auto-calculated Remaining Quantity:',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_calculateRemaining()} units',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.p16),
                      ],

                      // Date picker
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Production Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                            prefixIcon: const Icon(Icons.calendar_month_rounded),
                          ),
                          child: Text(
                            DateFormat('dd MMMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Status Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        items: statuses.map((String s) {
                          return DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatus = val;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                          ),
                          prefixIcon: const Icon(Icons.info_outline),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Supervisor Select Dropdown
                      employeesAsync.when(
                        loading: () => const Center(child: LinearProgressIndicator()),
                        error: (err, stack) => Text('Error loading supervisors: $err'),
                        data: (employeeList) {
                          final activeEmployees = employeeList.where((e) => e.status == 'Active').toList();

                          return DropdownButtonFormField<String>(
                            value: _selectedSupervisorId,
                            hint: const Text('Select Supervisor'),
                            items: activeEmployees.map((EmployeeModel emp) {
                              return DropdownMenuItem<String>(
                                value: emp.employeeId,
                                child: Text('${emp.name} (${emp.role})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSupervisorId = val;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Assigned Supervisor',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Assigned Employees Checklist Header
                      const Text(
                        'Assign Employees',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Employees Checklist
                      employeesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('Error loading employees: $err'),
                        data: (employeeList) {
                          final activeStaff = employeeList.where((e) => e.status == 'Active').toList();

                          if (activeStaff.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('No active employees found.', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeStaff.length,
                              itemBuilder: (context, idx) {
                                final emp = activeStaff[idx];
                                final isSelected = _selectedEmployeeIds.contains(emp.employeeId);

                                return CheckboxListTile(
                                  title: Text(emp.name),
                                  subtitle: Text('${emp.department} • ${emp.role}'),
                                  value: isSelected,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      if (val == true) {
                                        if (!_selectedEmployeeIds.contains(emp.employeeId)) {
                                          _selectedEmployeeIds.add(emp.employeeId);
                                        }
                                      } else {
                                        _selectedEmployeeIds.remove(emp.employeeId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.p20),

                      // Tooling Checklist Header
                      const Text(
                        'Select Tools Required',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p8),

                      // Tooling Checklist
                      ref.watch(companyToolsStreamProvider).when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('Error loading tools: $err'),
                        data: (toolList) {
                          final activeTools = toolList.where((t) => t.status == 'Active').toList();

                          if (activeTools.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('No active tools found in Tooling Master.', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeTools.length,
                              itemBuilder: (context, idx) {
                                final tool = activeTools[idx];
                                final isSelected = _selectedToolIds.contains(tool.toolId);

                                return CheckboxListTile(
                                  title: Text('${tool.toolName} (${tool.toolCode})'),
                                  subtitle: Text('Location: ${tool.location}'),
                                  value: isSelected,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      if (val == true) {
                                        if (!_selectedToolIds.contains(tool.toolId)) {
                                          _selectedToolIds.add(tool.toolId);
                                          _selectedToolNames.add(tool.toolName);
                                        }
                                      } else {
                                        _selectedToolIds.remove(tool.toolId);
                                        _selectedToolNames.remove(tool.toolName);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.p20),

                      // Drawing/Blueprint File Upload Container
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.p16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Blueprint / Design Document (Optional)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: AppSizes.p12),
                              if (_selectedFileName != null) ...[
                                Row(
                                  children: [
                                    Icon(
                                      _selectedFileExtension == 'pdf'
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.image_rounded,
                                      color: _selectedFileExtension == 'pdf'
                                          ? Colors.red
                                          : Colors.blue,
                                    ),
                                    const SizedBox(width: AppSizes.p8),
                                    Expanded(
                                      child: Text(
                                        _selectedFileName!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: AppColors.error),
                                      onPressed: _clearFile,
                                    ),
                                  ],
                                ),
                              ] else if (_drawingUrl != null && _drawingUrl!.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.cloud_done_rounded, color: Colors.green),
                                    const SizedBox(width: AppSizes.p8),
                                    Expanded(
                                      child: Text(
                                        _drawingFileName ?? 'Uploaded Document',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: AppColors.error),
                                      onPressed: () => setState(() {
                                        _drawingUrl = null;
                                        _drawingFileName = null;
                                      }),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                OutlinedButton.icon(
                                  onPressed: _pickFile,
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: const Text('Upload Drawing (PDF/Image)'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                            ),
                          ),
                          child: Text(
                            _isEdit ? 'Update Production' : 'Create Production',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
