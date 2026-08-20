import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/domain/models/inventory_item_model.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final String? purchaseId;
  const PurchaseFormScreen({super.key, this.purchaseId});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _invoiceNumberController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0.0');
  final _priceController = TextEditingController(text: '0.0');
  final _remarksController = TextEditingController();

  String _unit = kInventoryUnits[0];
  String _status = 'Pending';
  DateTime _purchaseDate = DateTime.now();

  bool _saving = false;
  bool _initialized = false;
  String? _originalStatus; // Tracks the initial status before updates

  @override
  void initState() {
    super.initState();
    // Add listeners to auto-calculate the total
    _quantityController.addListener(_onPriceOrQtyChanged);
    _priceController.addListener(_onPriceOrQtyChanged);
  }

  void _onPriceOrQtyChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    return qty * price;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.purchaseId != null;

    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isReadOnly = role != 'Owner';

    if (isEdit && !_initialized) {
      final purchaseDetailsAsync = ref.watch(purchaseDetailsStreamProvider(widget.purchaseId!));
      return purchaseDetailsAsync.when(
        data: (purchase) {
          if (purchase == null) {
            return ResponsiveScaffold(
              appBar: AppBar(title: const Text('Purchase Record Not Found')),
              body: const Center(child: Text('The requested purchase record could not be found.')),
            );
          }
          // Populate controllers
          _invoiceNumberController.text = purchase.invoiceNumber ?? '';
          _supplierNameController.text = purchase.supplierName;
          _supplierPhoneController.text = purchase.supplierPhone;
          _nameController.text = purchase.itemName;
          _quantityController.text = purchase.quantity.toString();
          _priceController.text = purchase.pricePerUnit.toString();
          _remarksController.text = purchase.remarks;
          _unit = purchase.unit;
          _status = purchase.status;
          _originalStatus = purchase.status;
          _purchaseDate = purchase.purchaseDate;
          _initialized = true;

          return _buildFormScaffold(theme, isEdit, isReadOnly);
        },
        loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => ResponsiveScaffold(
          body: Center(child: Text('Error loading purchase record: $err', style: TextStyle(color: theme.colorScheme.error))),
        ),
      );
    }

    return _buildFormScaffold(theme, isEdit, isReadOnly);
  }

  Widget _buildFormScaffold(ThemeData theme, bool isEdit, bool isReadOnly) {
    // Watch inventory stream to populate autocomplete recommendations
    final inventoryItemsAsync = ref.watch(companyInventoryStreamProvider);
    final inventoryItems = inventoryItemsAsync.value ?? [];
    final existingItemNames = inventoryItems.map((item) => item.itemName).toList();

    final titlePrefix = isReadOnly ? 'View' : (isEdit ? 'Edit' : 'Add');

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('$titlePrefix Purchase Record'),
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
                            if (isReadOnly)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: AppSizes.p16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.colorScheme.primary, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'You have View Only access to this purchase record.',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Invoice Number
                            TextFormField(
                              controller: _invoiceNumberController,
                              enabled: !isReadOnly,
                              decoration: InputDecoration(
                                labelText: 'Invoice Number (Optional)',
                                hintText: 'e.g., INV-98124',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Supplier Details
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _supplierNameController,
                                  enabled: !isReadOnly,
                                  decoration: InputDecoration(
                                    labelText: 'Supplier Name *',
                                    hintText: 'e.g., Acme Fasteners',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Supplier Name is required';
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _supplierPhoneController,
                                  enabled: !isReadOnly,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Supplier Phone *',
                                    hintText: 'e.g., 9876543210',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Supplier Phone is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Item Name Autocomplete & Unit
                            ResponsiveFormRow(
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) => Autocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return const Iterable<String>.empty();
                                      }
                                      return existingItemNames.where((option) {
                                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                      });
                                    },
                                    onSelected: (selection) {
                                      _nameController.text = selection;
                                      final matchingItem = inventoryItems.firstWhere(
                                        (item) => item.itemName.toLowerCase() == selection.toLowerCase(),
                                        orElse: () => inventoryItems.first, // fallback
                                      );
                                      if (matchingItem.itemName.toLowerCase() == selection.toLowerCase()) {
                                        setState(() {
                                          _unit = matchingItem.unit;
                                        });
                                      }
                                    },
                                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                      if (_initialized && textEditingController.text != _nameController.text) {
                                        textEditingController.text = _nameController.text;
                                      }
                                      textEditingController.addListener(() {
                                        _nameController.text = textEditingController.text;
                                      });

                                      return TextFormField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        enabled: !isReadOnly,
                                        decoration: InputDecoration(
                                          labelText: 'Item Name *',
                                          hintText: 'Search or add item...',
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
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4.0,
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            width: constraints.maxWidth,
                                            height: 200,
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              itemBuilder: (BuildContext context, int index) {
                                                final option = options.elementAt(index);
                                                return ListTile(
                                                  title: Text(option),
                                                  onTap: () => onSelected(option),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                DropdownButtonFormField<String>(
                                  value: _unit,
                                  disabledHint: Text(_unit),
                                  decoration: InputDecoration(
                                    labelText: 'Unit *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: kInventoryUnits.map((u) {
                                    return DropdownMenuItem(value: u, child: Text(u));
                                  }).toList(),
                                  onChanged: isReadOnly
                                      ? null
                                      : (val) {
                                          if (val != null) {
                                            setState(() => _unit = val);
                                          }
                                        },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Quantity & Price
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _quantityController,
                                  enabled: !isReadOnly,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Quantity is required';
                                    }
                                    final number = double.tryParse(val);
                                    if (number == null || number <= 0) {
                                      return 'Enter number > 0';
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _priceController,
                                  enabled: !isReadOnly,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Price Per Unit *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Price is required';
                                    }
                                    final number = double.tryParse(val);
                                    if (number == null || number < 0) {
                                      return 'Enter number >= 0';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Total Amount display (Read Only)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withAlpha(10),
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                border: Border.all(color: theme.dividerColor.withAlpha(50)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount (Auto-Calculated)',
                                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(180), fontSize: 13),
                                  ),
                                  Text(
                                    '\$${_totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Purchase Date Picker
                            InkWell(
                              onTap: isReadOnly ? null : () => _selectDate(context),
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Purchase Date *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_purchaseDate.day}/${_purchaseDate.month}/${_purchaseDate.year}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Status Dropdown
                            DropdownButtonFormField<String>(
                              value: _status,
                              disabledHint: Text(_status),
                              decoration: InputDecoration(
                                labelText: 'Status *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'Received', child: Text('Received')),
                                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                              ],
                              onChanged: isReadOnly
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() => _status = val);
                                      }
                                    },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Remarks
                            TextFormField(
                              controller: _remarksController,
                              enabled: !isReadOnly,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Remarks (Optional)',
                                hintText: 'Enter internal notes, terms, etc...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p32),

                            // Save Button (Only if not read only)
                            if (!isReadOnly)
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
                                    isEdit ? 'Save Changes' : 'Create Purchase',
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No company workspace detected.')),
      );
      return;
    }

    final inputItemName = _nameController.text.trim();
    final quantity = double.parse(_quantityController.text.trim());

    // Fetch existing inventory list to check if item exists
    final inventoryItems = ref.read(companyInventoryStreamProvider).value ?? [];
    
    InventoryItemModel? existingInventoryItem;
    for (final item in inventoryItems) {
      if (item.itemName.toLowerCase().trim() == inputItemName.toLowerCase().trim()) {
        existingInventoryItem = item;
        break;
      }
    }

    // Determine if we need to update stock
    final transitioningToReceived = _status == 'Received' && _originalStatus != 'Received';

    if (transitioningToReceived) {
      if (existingInventoryItem == null) {
        // Show dialog asking whether to create the item
        final bool? shouldCreate = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Item Not Found in Inventory'),
              content: Text('This item "$inputItemName" does not exist in Inventory.\nWould you like to create it?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        if (shouldCreate == null) return; // Dialog was cancelled/dismissed somehow

        setState(() => _saving = true);

        if (shouldCreate) {
          try {
            // Auto create item in inventory
            final invRepo = ref.read(inventoryRepositoryProvider);
            final newItemId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('inventory').doc().id;
            
            final newInvItem = InventoryItemModel(
              itemId: newItemId,
              companyId: companyId,
              itemName: inputItemName,
              category: 'Others',
              currentStock: quantity, // Stock initialized with purchase qty
              unit: _unit,
              supplierName: _supplierNameController.text.trim(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              date: DateTime.now(),
              documentNumber: 'AUTO-PO',
              partNumber: 'N/A',
              process: 'Purchase',
              withMaterial: true,
            );
            
            await invRepo.createItem(companyId, newInvItem);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to auto-create inventory item: $e')),
              );
            }
            setState(() => _saving = false);
            return;
          }
        }
      } else {
        // Inventory item exists, increase stock
        setState(() => _saving = true);
        try {
          final invRepo = ref.read(inventoryRepositoryProvider);
          final updatedInvItem = existingInventoryItem.copyWith(
            currentStock: existingInventoryItem.currentStock + quantity,
            updatedAt: DateTime.now(),
          );
          await invRepo.updateItem(companyId, updatedInvItem);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update inventory stock: $e')),
            );
          }
          setState(() => _saving = false);
          return;
        }
      }
    } else {
      // Just start saving screen state
      setState(() => _saving = true);
    }

    // Now save the purchase document itself
    try {
      final purchaseRepo = ref.read(purchaseRepositoryProvider);

      if (widget.purchaseId != null) {
        // Edit Mode
        final purchaseDetailsAsync = ref.read(purchaseDetailsStreamProvider(widget.purchaseId!));
        final existingPurchase = purchaseDetailsAsync.value;
        if (existingPurchase != null) {
          final updatedPurchase = existingPurchase.copyWith(
            invoiceNumber: _invoiceNumberController.text.trim().isEmpty ? null : _invoiceNumberController.text.trim(),
            supplierName: _supplierNameController.text.trim(),
            supplierPhone: _supplierPhoneController.text.trim(),
            itemName: inputItemName,
            quantity: quantity,
            unit: _unit,
            pricePerUnit: double.parse(_priceController.text.trim()),
            totalAmount: _totalAmount,
            purchaseDate: _purchaseDate,
            remarks: _remarksController.text.trim(),
            status: _status,
            updatedAt: DateTime.now(),
          );
          await purchaseRepo.updatePurchase(companyId, updatedPurchase);

          // Trigger notification
          await ref.read(notificationServiceProvider).notifyPurchaseAddedOrReceived(
            companyId: companyId,
            purchaseId: updatedPurchase.purchaseId,
            purchaseNumber: updatedPurchase.purchaseNumber,
            itemName: updatedPurchase.itemName,
            supplierName: updatedPurchase.supplierName,
            status: updatedPurchase.status,
            userUid: authState.user?.uid ?? '',
            userName: authState.user?.name ?? 'System',
          );
        }
      } else {
        // Create Mode - Auto generate purchase number PUR-XXXX
        final existingPurchases = ref.read(companyPurchasesStreamProvider).value ?? [];
        int nextNum = 1;
        for (final p in existingPurchases) {
          final numStr = p.purchaseNumber.replaceFirst('PUR-', '');
          final numVal = int.tryParse(numStr);
          if (numVal != null && numVal >= nextNum) {
            nextNum = numVal + 1;
          }
        }
        final generatedPurchaseNumber = 'PUR-${nextNum.toString().padLeft(4, '0')}';

        final newPurchaseId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('purchases').doc().id;
        final newPurchase = PurchaseModel(
          purchaseId: newPurchaseId,
          companyId: companyId,
          purchaseNumber: generatedPurchaseNumber,
          invoiceNumber: _invoiceNumberController.text.trim().isEmpty ? null : _invoiceNumberController.text.trim(),
          supplierName: _supplierNameController.text.trim(),
          supplierPhone: _supplierPhoneController.text.trim(),
          itemName: inputItemName,
          quantity: quantity,
          unit: _unit,
          pricePerUnit: double.parse(_priceController.text.trim()),
          totalAmount: _totalAmount,
          purchaseDate: _purchaseDate,
          remarks: _remarksController.text.trim(),
          status: _status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await purchaseRepo.createPurchase(companyId, newPurchase);

        // Trigger notification
        await ref.read(notificationServiceProvider).notifyPurchaseAddedOrReceived(
          companyId: companyId,
          purchaseId: newPurchase.purchaseId,
          purchaseNumber: newPurchase.purchaseNumber,
          itemName: newPurchase.itemName,
          supplierName: newPurchase.supplierName,
          status: newPurchase.status,
          userUid: authState.user?.uid ?? '',
          userName: authState.user?.name ?? 'System',
        );
      }



      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.purchaseId != null ? 'Purchase updated successfully.' : 'Purchase created successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving purchase record: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
