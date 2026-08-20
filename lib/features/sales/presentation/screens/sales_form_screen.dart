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
import '../../domain/models/sale_model.dart';
import '../providers/sales_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class SalesFormScreen extends ConsumerStatefulWidget {
  final String? saleId;
  const SalesFormScreen({super.key, this.saleId});

  @override
  ConsumerState<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends ConsumerState<SalesFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _invoiceNumberController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0.0');
  final _priceController = TextEditingController(text: '0.0');
  final _remarksController = TextEditingController();

  String _unit = kInventoryUnits[0];
  String _status = 'Pending';
  DateTime _saleDate = DateTime.now();

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
    _customerNameController.dispose();
    _customerPhoneController.dispose();
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
    final isEdit = widget.saleId != null;

    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isReadOnly = role != 'Owner';

    if (isEdit && !_initialized) {
      final saleDetailsAsync = ref.watch(saleDetailsStreamProvider(widget.saleId!));
      return saleDetailsAsync.when(
        data: (sale) {
          if (sale == null) {
            return ResponsiveScaffold(
              appBar: AppBar(title: const Text('Sale Record Not Found')),
              body: const Center(child: Text('The requested sale record could not be found.')),
            );
          }
          // Populate controllers
          _invoiceNumberController.text = sale.invoiceNumber ?? '';
          _customerNameController.text = sale.customerName;
          _customerPhoneController.text = sale.customerPhone;
          _nameController.text = sale.itemName;
          _quantityController.text = sale.quantity.toString();
          _priceController.text = sale.pricePerUnit.toString();
          _remarksController.text = sale.remarks;
          _unit = sale.unit;
          _status = sale.status;
          _originalStatus = sale.status;
          _saleDate = sale.saleDate;
          _initialized = true;

          return _buildFormScaffold(theme, isEdit, isReadOnly);
        },
        loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => ResponsiveScaffold(
          body: Center(child: Text('Error loading sale record: $err', style: TextStyle(color: theme.colorScheme.error))),
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
        title: Text('$titlePrefix Sale Record'),
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
                                        'You have View Only access to this sale record.',
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
                                hintText: 'e.g., INV-77192',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Customer Details
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _customerNameController,
                                  enabled: !isReadOnly,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name *',
                                    hintText: 'e.g., John Doe',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Customer Name is required';
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _customerPhoneController,
                                  enabled: !isReadOnly,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Phone *',
                                    hintText: 'e.g., 9876543210',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Customer Phone is required';
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
                                          hintText: 'Search inventory or add...',
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

                            // Sale Date Picker
                            InkWell(
                              onTap: isReadOnly ? null : () => _selectDate(context),
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Sale Date *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
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
                                DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
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
                                    isEdit ? 'Save Changes' : 'Create Sale',
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
      initialDate: _saleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
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

    // Fetch existing inventory list to check if item exists and has stock
    final inventoryItems = ref.read(companyInventoryStreamProvider).value ?? [];

    InventoryItemModel? existingInventoryItem;
    for (final item in inventoryItems) {
      if (item.itemName.toLowerCase().trim() == inputItemName.toLowerCase().trim()) {
        existingInventoryItem = item;
        break;
      }
    }

    // Determine if we need to deduct stock
    final transitioningToDelivered = _status == 'Delivered' && _originalStatus != 'Delivered';

    if (transitioningToDelivered) {
      if (existingInventoryItem == null) {
        // Item doesn't exist, show warning and block saving
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Insufficient Stock'),
              content: Text('This item "$inputItemName" does not exist in Inventory.\nInsufficient stock available.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      // Verify available stock
      final availableStock = existingInventoryItem.currentStock;
      if (availableStock < quantity) {
        // Insufficient stock, show warning and block saving
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Insufficient Stock'),
              content: Text(
                'Insufficient stock available.\n\n'
                'Remaining stock: $availableStock ${_unit}\n'
                'Requested: $quantity ${_unit}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      // Stock is sufficient, show the confirmation dialog
      final bool? confirmDelivery = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Confirm Sale Delivery'),
            content: Text(
              'Inventory stock will be reduced permanently by $quantity $_unit.\n'
              'Do you want to proceed and mark this sale as Delivered?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Proceed'),
              ),
            ],
          );
        },
      );

      if (confirmDelivery != true) return; // User cancelled

      setState(() => _saving = true);

      // Deduct stock in database
      try {
        final invRepo = ref.read(inventoryRepositoryProvider);
        final updatedInvItem = existingInventoryItem.copyWith(
          currentStock: availableStock - quantity,
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
    } else {
      // Just start saving screen state
      setState(() => _saving = true);
    }

    // Now save the sale document itself
    try {
      final saleRepo = ref.read(saleRepositoryProvider);

      if (widget.saleId != null) {
        // Edit Mode
        final saleDetailsAsync = ref.read(saleDetailsStreamProvider(widget.saleId!));
        final existingSale = saleDetailsAsync.value;
        if (existingSale != null) {
          final updatedSale = existingSale.copyWith(
            invoiceNumber: _invoiceNumberController.text.trim().isEmpty ? null : _invoiceNumberController.text.trim(),
            customerName: _customerNameController.text.trim(),
            customerPhone: _customerPhoneController.text.trim(),
            itemName: inputItemName,
            quantity: quantity,
            unit: _unit,
            pricePerUnit: double.parse(_priceController.text.trim()),
            totalAmount: _totalAmount,
            saleDate: _saleDate,
            remarks: _remarksController.text.trim(),
            status: _status,
            updatedAt: DateTime.now(),
          );
          await saleRepo.updateSale(companyId, updatedSale);

          // Trigger sale notification
          await ref.read(notificationServiceProvider).notifySaleAddedOrDelivered(
            companyId: companyId,
            saleId: updatedSale.saleId,
            saleNumber: updatedSale.saleNumber,
            itemName: updatedSale.itemName,
            customerName: updatedSale.customerName,
            status: updatedSale.status,
            totalAmount: updatedSale.totalAmount,
            userUid: authState.user?.uid ?? '',
            userName: authState.user?.name ?? 'System',
          );
        }
      } else {
        // Create Mode - Auto generate sale number SAL-XXXX
        final existingSales = ref.read(companySalesStreamProvider).value ?? [];
        int nextNum = 1;
        for (final s in existingSales) {
          final numStr = s.saleNumber.replaceFirst('SAL-', '');
          final numVal = int.tryParse(numStr);
          if (numVal != null && numVal >= nextNum) {
            nextNum = numVal + 1;
          }
        }
        final generatedSaleNumber = 'SAL-${nextNum.toString().padLeft(4, '0')}';

        final newSaleId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('sales').doc().id;
        final newSale = SaleModel(
          saleId: newSaleId,
          companyId: companyId,
          saleNumber: generatedSaleNumber,
          invoiceNumber: _invoiceNumberController.text.trim().isEmpty ? null : _invoiceNumberController.text.trim(),
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.trim(),
          itemName: inputItemName,
          quantity: quantity,
          unit: _unit,
          pricePerUnit: double.parse(_priceController.text.trim()),
          totalAmount: _totalAmount,
          saleDate: _saleDate,
          remarks: _remarksController.text.trim(),
          status: _status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await saleRepo.createSale(companyId, newSale);

        // Trigger sale notification
        await ref.read(notificationServiceProvider).notifySaleAddedOrDelivered(
          companyId: companyId,
          saleId: newSale.saleId,
          saleNumber: newSale.saleNumber,
          itemName: newSale.itemName,
          customerName: newSale.customerName,
          status: newSale.status,
          totalAmount: newSale.totalAmount,
          userUid: authState.user?.uid ?? '',
          userName: authState.user?.name ?? 'System',
        );
      }



      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.saleId != null ? 'Sale updated successfully.' : 'Sale created successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving sale record: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
