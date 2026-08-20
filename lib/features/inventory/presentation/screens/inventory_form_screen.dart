import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../domain/models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/polish_widgets.dart';

class InventoryFormScreen extends ConsumerStatefulWidget {
  final String? itemId;
  const InventoryFormScreen({super.key, this.itemId});

  @override
  ConsumerState<InventoryFormScreen> createState() => _InventoryFormScreenState();
}

class _InventoryFormScreenState extends ConsumerState<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _currentStockController = TextEditingController(text: '0.0');
  final _supplierNameController = TextEditingController();
  
  // New field controllers
  final _documentNumberController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _processController = TextEditingController();

  String _category = kInventoryCategories[0];
  String _unit = kInventoryUnits[0];
  
  // New state variables
  DateTime _date = DateTime.now();
  bool _withMaterial = false;
  
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _currentStockController.dispose();
    _supplierNameController.dispose();
    _documentNumberController.dispose();
    _partNumberController.dispose();
    _processController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.itemId != null;

    if (isEdit && !_initialized) {
      final itemDetailsAsync = ref.watch(inventoryDetailsStreamProvider(widget.itemId!));
      return itemDetailsAsync.when(
        data: (item) {
          if (item == null) {
            return ResponsiveScaffold(
              appBar: AppBar(title: const Text('Item Not Found')),
              body: const Center(child: Text('The requested inventory item could not be found.')),
            );
          }
          // Populate controllers
          _nameController.text = item.itemName;
          _currentStockController.text = item.currentStock.toString();
          _supplierNameController.text = item.supplierName ?? '';
          _category = item.category;
          _unit = item.unit;
          
          // Populate new fields
          _date = item.date;
          _documentNumberController.text = item.documentNumber;
          _partNumberController.text = item.partNumber;
          _processController.text = item.process;
          _withMaterial = item.withMaterial;
          
          _initialized = true;
 
          return _buildFormScaffold(theme, isEdit);
        },
        loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => ResponsiveScaffold(
          body: Center(child: Text('Error loading item: $err', style: TextStyle(color: theme.colorScheme.error))),
        ),
      );
    }

    return _buildFormScaffold(theme, isEdit);
  }

  Widget _buildFormScaffold(ThemeData theme, bool isEdit) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Inventory Item' : 'Add Inventory Item'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Name
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Item Name *',
                                hintText: 'e.g., M10 Steel Bolts',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Item Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Date Field
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Date *',
                                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat('yyyy-MM-dd').format(_date),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Document Number & Part Number
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _documentNumberController,
                                  decoration: InputDecoration(
                                    labelText: 'Document Number *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Document Number is required';
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _partNumberController,
                                  decoration: InputDecoration(
                                    labelText: 'Part Number *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Part Number is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Category & Unit
                            ResponsiveFormRow(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _category,
                                  decoration: InputDecoration(
                                    labelText: 'Category *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: kInventoryCategories.map((cat) {
                                    return DropdownMenuItem(value: cat, child: Text(cat));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _category = val);
                                    }
                                  },
                                ),
                                DropdownButtonFormField<String>(
                                  value: _unit,
                                  decoration: InputDecoration(
                                    labelText: 'Unit *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: kInventoryUnits.map((u) {
                                    return DropdownMenuItem(value: u, child: Text(u));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _unit = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Which Process & With Material?
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _processController,
                                  decoration: InputDecoration(
                                    labelText: 'Which Process? *',
                                    hintText: 'e.g., Cutting, Milling',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Process is required';
                                    }
                                    return null;
                                  },
                                ),
                                DropdownButtonFormField<bool>(
                                  value: _withMaterial,
                                  decoration: InputDecoration(
                                    labelText: 'With Material? *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: true, child: Text('Yes')),
                                    DropdownMenuItem(value: false, child: Text('No')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _withMaterial = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Current Stock
                            TextFormField(
                              controller: _currentStockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Current Stock *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Current Stock is required';
                                }
                                final number = double.tryParse(val);
                                if (number == null || number < 0) {
                                  return 'Enter a valid positive number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Optional Supplier Name
                            TextFormField(
                              controller: _supplierNameController,
                              decoration: InputDecoration(
                                labelText: 'Supplier Name (Optional)',
                                hintText: 'e.g., Acme Fasteners Ltd.',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p32),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                  ),
                                ),
                                child: Text(
                                  isEdit ? 'Save Changes' : 'Add Item to Inventory',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
            ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId == null) {
      showFeedbackSnackBar(
        context: context,
        message: 'Error: No company workspace detected.',
        isError: true,
      );
      return;
    }

    final inputName = _nameController.text.trim();

    // Validate duplicate item name
    final inventoryListAsync = ref.read(companyInventoryStreamProvider);
    final existingItems = inventoryListAsync.value ?? [];

    final isDuplicate = existingItems.any((item) {
      final nameMatches = item.itemName.toLowerCase() == inputName.toLowerCase();
      if (widget.itemId != null) {
        // Edit mode: matches other items excluding itself
        return nameMatches && item.itemId != widget.itemId;
      }
      return nameMatches;
    });

    if (isDuplicate) {
      showFeedbackSnackBar(
        context: context,
        message: 'An item with the name "$inputName" already exists in inventory.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      
      final authState = ref.read(authProvider);
      final userUid = authState.user?.uid ?? '';
      final userName = authState.user?.name ?? 'System';

      if (widget.itemId != null) {
        // Edit Mode
        final existingItem = ref.read(inventoryDetailsStreamProvider(widget.itemId!)).value;
        if (existingItem != null) {
          final updatedItem = existingItem.copyWith(
            itemName: inputName,
            category: _category,
            currentStock: double.parse(_currentStockController.text.trim()),
            unit: _unit,
            supplierName: _supplierNameController.text.trim().isEmpty ? null : _supplierNameController.text.trim(),
            date: _date,
            documentNumber: _documentNumberController.text.trim(),
            partNumber: _partNumberController.text.trim(),
            process: _processController.text.trim(),
            withMaterial: _withMaterial,
            updatedAt: DateTime.now(),
          );
          await repo.updateItem(companyId, updatedItem);
        }
      } else {
        // Create Mode
        final docId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('inventory').doc().id;
        final newItem = InventoryItemModel(
          itemId: docId,
          companyId: companyId,
          itemName: inputName,
          category: _category,
          currentStock: double.parse(_currentStockController.text.trim()),
          unit: _unit,
          supplierName: _supplierNameController.text.trim().isEmpty ? null : _supplierNameController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          date: _date,
          documentNumber: _documentNumberController.text.trim(),
          partNumber: _partNumberController.text.trim(),
          process: _processController.text.trim(),
          withMaterial: _withMaterial,
        );
        await repo.createItem(companyId, newItem);

        // Trigger item created notification
        await ref.read(notificationServiceProvider).notifyInventoryItemCreated(
          companyId: companyId,
          itemId: newItem.itemId,
          itemName: newItem.itemName,
          category: newItem.category,
          userUid: userUid,
          userName: userName,
        );
      }

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: widget.itemId != null ? 'Item updated successfully.' : 'Item added successfully.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error saving item: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
