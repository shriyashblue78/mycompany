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

import '../../../party/domain/models/party_model.dart';
import '../../../party/presentation/providers/party_provider.dart';

class SalesFormScreen extends ConsumerStatefulWidget {
  final String? saleId;
  const SalesFormScreen({super.key, this.saleId});

  @override
  ConsumerState<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends ConsumerState<SalesFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPartyId;
  final _partySearchController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _partyTypeController = TextEditingController();
  final _vendorCodeController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _stateController = TextEditingController();
  final _stateCodeController = TextEditingController();
  final _addressController = TextEditingController();

  final _itemNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '0.0');
  final _priceController = TextEditingController(text: '0.0');
  final _remarksController = TextEditingController();

  String _unit = kInventoryUnits[0];
  String _status = 'Pending';
  String _approvalStatus = 'Approved';
  DateTime _saleDate = DateTime.now();

  bool _saving = false;
  bool _initialized = false;
  String? _originalStatus;
  SaleModel? _existingSale;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_onPriceOrQtyChanged);
    _priceController.addListener(_onPriceOrQtyChanged);
  }

  void _onPriceOrQtyChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _partySearchController.dispose();
    _invoiceNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _partyTypeController.dispose();
    _vendorCodeController.dispose();
    _contactPersonNameController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _stateController.dispose();
    _stateCodeController.dispose();
    _addressController.dispose();
    _itemNumberController.dispose();
    _nameController.dispose();
    _hsnCodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _populatePartyDetails(PartyModel party) {
    setState(() {
      _selectedPartyId = party.partyId;
      _partySearchController.text = '${party.partyName} (GSTIN: ${party.gstin.isNotEmpty ? party.gstin : "N/A"})';
      _customerNameController.text = party.partyName;
      _customerPhoneController.text = party.contactNumber;
      _partyTypeController.text = party.partyType;
      _vendorCodeController.text = party.vendorCode;
      _contactPersonNameController.text = party.contactPersonName;
      _emailController.text = party.email;
      _gstinController.text = party.gstin;
      _stateController.text = party.state;
      _stateCodeController.text = party.stateCode;
      _addressController.text = party.address;
    });
  }

  void _clearPartyDetails() {
    setState(() {
      _selectedPartyId = null;
      _partySearchController.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _partyTypeController.clear();
      _vendorCodeController.clear();
      _contactPersonNameController.clear();
      _emailController.clear();
      _gstinController.clear();
      _stateController.clear();
      _stateCodeController.clear();
      _addressController.clear();
    });
  }

  double get _totalAmount {
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    return qty * price;
  }

  String _generateUniqueInvoiceNumber(List<SaleModel> existingSales) {
    int maxInvNum = 0;
    for (final s in existingSales) {
      final inv = s.invoiceNumber;
      if (inv != null && inv.startsWith('INV-')) {
        final numPart = inv.replaceFirst('INV-', '');
        final val = int.tryParse(numPart);
        if (val != null && val > maxInvNum) {
          maxInvNum = val;
        }
      }
    }
    return 'INV-${(maxInvNum + 1).toString().padLeft(5, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.saleId != null;

    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isReadOnly = role != 'Owner' && role != 'Accountant';
    final isAccountant = role == 'Accountant';
    final isOwner = role == 'Owner';

    if (!isEdit && !_initialized) {
      final existingSales = ref.watch(companySalesStreamProvider).value ?? [];
      _invoiceNumberController.text = _generateUniqueInvoiceNumber(existingSales);
      _initialized = true;
    }

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
          _existingSale = sale;
          _selectedPartyId = sale.partyId;
          _invoiceNumberController.text = sale.invoiceNumber ?? '';
          _customerNameController.text = sale.customerName;
          _customerPhoneController.text = sale.customerPhone;
          _partyTypeController.text = sale.partyType;
          _vendorCodeController.text = sale.vendorCode;
          _contactPersonNameController.text = sale.contactPersonName;
          _emailController.text = sale.email;
          _gstinController.text = sale.gstin;
          _stateController.text = sale.state;
          _stateCodeController.text = sale.stateCode;
          _addressController.text = sale.address;

          if (sale.customerName.isNotEmpty) {
            _partySearchController.text = '${sale.customerName}${sale.gstin.isNotEmpty ? " (GSTIN: ${sale.gstin})" : ""}';
          }

          _itemNumberController.text = sale.itemNumber;
          _nameController.text = sale.itemName;
          _hsnCodeController.text = sale.hsnCode;
          _quantityController.text = sale.quantity.toString();
          _priceController.text = sale.pricePerUnit.toString();
          _remarksController.text = sale.remarks;
          _unit = sale.unit;
          _status = sale.status;
          _approvalStatus = sale.approvalStatus;
          _originalStatus = sale.status;
          _saleDate = sale.saleDate;
          _initialized = true;

          return _buildFormScaffold(theme, isEdit, isReadOnly, isAccountant, isOwner);
        },
        loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => ResponsiveScaffold(
          body: Center(child: Text('Error loading sale record: $err', style: TextStyle(color: theme.colorScheme.error))),
        ),
      );
    }

    return _buildFormScaffold(theme, isEdit, isReadOnly, isAccountant, isOwner);
  }

  Widget _buildFormScaffold(ThemeData theme, bool isEdit, bool isReadOnly, bool isAccountant, bool isOwner) {
    final inventoryItemsAsync = ref.watch(companyInventoryStreamProvider);
    final inventoryItems = inventoryItemsAsync.value ?? [];
    final existingItemNames = inventoryItems.map((item) => item.itemName).toList();

    final titlePrefix = isReadOnly ? 'View' : (isEdit ? 'Edit' : 'Log');

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
                    constraints: const BoxConstraints(maxWidth: 750),
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
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'You have View Only access to this sale record.',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_approvalStatus == 'Pending Approval')
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: AppSizes.p16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade700),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.pending_actions_rounded, color: Colors.amber),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        isOwner
                                            ? 'Pending Owner Approval. Click "Approve Request" below to approve.'
                                            : 'This Sale entry is Pending Owner Approval.',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                                    if (isOwner && isEdit) ...[
                                      ElevatedButton(
                                        onPressed: _approveByOwner,
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        child: const Text('Approve', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                            // Party / Company Selection (Autocomplete Search by Name, GSTIN, Vendor Code)
                            Consumer(
                              builder: (context, ref, child) {
                                final partiesListAsync = ref.watch(companyPartiesStreamProvider);
                                final parties = partiesListAsync.value ?? [];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) => RawAutocomplete<PartyModel>(
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return const Iterable<PartyModel>.empty();
                                          }
                                          final q = textEditingValue.text.toLowerCase().trim();
                                          return parties.where((PartyModel party) {
                                            final nameMatch = party.partyName.toLowerCase().contains(q);
                                            final gstinMatch = party.gstin.toLowerCase().contains(q);
                                            final vendorCodeMatch = party.vendorCode.toLowerCase().contains(q);
                                            return nameMatch || gstinMatch || vendorCodeMatch;
                                          });
                                        },
                                        displayStringForOption: (PartyModel option) => '${option.partyName} (GSTIN: ${option.gstin.isNotEmpty ? option.gstin : "N/A"})',
                                        onSelected: (PartyModel selection) {
                                          _populatePartyDetails(selection);
                                        },
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          if (_partySearchController.text.isNotEmpty && textEditingController.text != _partySearchController.text) {
                                            textEditingController.text = _partySearchController.text;
                                          }
                                          return TextFormField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            enabled: !isReadOnly,
                                            decoration: InputDecoration(
                                              labelText: 'Search & Select Party / Company Master',
                                              hintText: 'Search by Party Name, GSTIN, or Vendor Code...',
                                              prefixIcon: const Icon(Icons.business_rounded, color: Colors.blue),
                                              suffixIcon: _selectedPartyId != null
                                                  ? IconButton(
                                                      icon: const Icon(Icons.clear_rounded),
                                                      onPressed: isReadOnly
                                                          ? null
                                                          : () {
                                                              textEditingController.clear();
                                                              _clearPartyDetails();
                                                            },
                                                    )
                                                  : null,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                              ),
                                            ),
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
                                                height: 220,
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  itemCount: options.length,
                                                  itemBuilder: (BuildContext context, int index) {
                                                    final party = options.elementAt(index);
                                                    return ListTile(
                                                      leading: Icon(
                                                        party.partyType == 'Customer' ? Icons.person_rounded : Icons.store_rounded,
                                                        color: party.partyType == 'Customer' ? Colors.blue : Colors.orange,
                                                      ),
                                                      title: Text(party.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                      subtitle: Text(
                                                        [
                                                          '${party.partyType}',
                                                          if (party.gstin.isNotEmpty) 'GSTIN: ${party.gstin}',
                                                          if (party.vendorCode.isNotEmpty) 'Code: ${party.vendorCode}',
                                                        ].join(' · '),
                                                        style: const TextStyle(fontSize: 12),
                                                      ),
                                                      onTap: () => onSelected(party),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: AppSizes.p16),
                                  ],
                                );
                              },
                            ),

                            // Invoice Number & Customer Name
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _invoiceNumberController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: 'Invoice Number (Auto-generated)',
                                    hintText: 'System Generated',
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _customerNameController,
                                  enabled: !isReadOnly,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name *',
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
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Customer Phone & Item Number
                            ResponsiveFormRow(
                              children: [
                                TextFormField(
                                  controller: _customerPhoneController,
                                  enabled: !isReadOnly,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Phone *',
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
                                TextFormField(
                                  controller: _itemNumberController,
                                  enabled: !isReadOnly,
                                  decoration: InputDecoration(
                                    labelText: 'Item Number (Optional)',
                                    hintText: 'e.g. ITM-001',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Item Name & HSN Code
                            ResponsiveFormRow(
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) => RawAutocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return const Iterable<String>.empty();
                                      }
                                      return existingItemNames.where((String option) {
                                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                      });
                                    },
                                    onSelected: (String selection) {
                                      _nameController.text = selection;
                                      for (final item in inventoryItems) {
                                        if (item.itemName.toLowerCase().trim() == selection.toLowerCase().trim()) {
                                          setState(() => _unit = item.unit);
                                          break;
                                        }
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
                                TextFormField(
                                  controller: _hsnCodeController,
                                  enabled: !isReadOnly,
                                  decoration: InputDecoration(
                                    labelText: 'HSN Code (Optional)',
                                    hintText: 'e.g. 8471',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Unit, Quantity & Price
                            ResponsiveFormRow(
                              children: [
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
                                    labelText: 'Price Per Unit (₹) *',
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
                                      return 'Enter valid price';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Total Display Card
                            Container(
                              padding: const EdgeInsets.all(AppSizes.p16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Calculated Total:',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '₹${_totalAmount.toStringAsFixed(2)}',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Sale Date
                            InkWell(
                              onTap: isReadOnly ? null : () => _selectDate(context),
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
                                    Text('${_saleDate.day}/${_saleDate.month}/${_saleDate.year}'),
                                    const Icon(Icons.calendar_today_rounded, size: 18),
                                  ],
                                ),
                              ),
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

                            // Action Button
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
                                    isAccountant
                                        ? (isEdit ? 'Submit Update for Approval' : 'Submit Logged Sale')
                                        : (isEdit ? 'Save Logged Sale' : 'Log Sale'),
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

  Future<void> _approveByOwner() async {
    if (_existingSale == null) return;
    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    if (companyId == null) return;

    setState(() => _saving = true);
    try {
      final saleRepo = ref.read(saleRepositoryProvider);
      final approvedSale = _existingSale!.copyWith(
        approvalStatus: 'Approved',
        lastModifiedByUid: authState.user?.uid,
        lastModifiedByName: authState.user?.name,
        lastModifiedByRole: 'Owner',
        updatedAt: DateTime.now(),
      );
      await saleRepo.updateSale(companyId, approvedSale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale record approved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving sale: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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

    final role = authState.selectedRole ?? 'Employee';
    final isAccountant = role == 'Accountant';
    final isOwner = role == 'Owner';

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

    final transitioningToDelivered = _status == 'Delivered' && _originalStatus != 'Delivered';

    if (transitioningToDelivered && isOwner) {
      if (existingInventoryItem == null) {
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

      final availableStock = existingInventoryItem.currentStock;
      if (availableStock < quantity) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Insufficient Stock'),
              content: Text(
                'Insufficient stock available.\n\n'
                'Remaining stock: $availableStock $_unit\n'
                'Requested: $quantity $_unit',
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

      final confirmDelivery = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Confirm Inventory Stock Deduction'),
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

      if (confirmDelivery != true) return;

      setState(() => _saving = true);

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
      setState(() => _saving = true);
    }

    try {
      final saleRepo = ref.read(saleRepositoryProvider);
      final newApprovalStatus = isAccountant ? 'Pending Approval' : 'Approved';

      if (widget.saleId != null) {
        // Edit Mode
        final saleDetailsAsync = ref.read(saleDetailsStreamProvider(widget.saleId!));
        final existingSale = saleDetailsAsync.value;
        if (existingSale != null) {
          final updatedSale = existingSale.copyWith(
            partyId: _selectedPartyId,
            invoiceNumber: _invoiceNumberController.text.trim().isEmpty ? null : _invoiceNumberController.text.trim(),
            customerName: _customerNameController.text.trim(),
            customerPhone: _customerPhoneController.text.trim(),
            partyType: _partyTypeController.text.trim(),
            vendorCode: _vendorCodeController.text.trim(),
            contactPersonName: _contactPersonNameController.text.trim(),
            email: _emailController.text.trim(),
            gstin: _gstinController.text.trim(),
            state: _stateController.text.trim(),
            stateCode: _stateCodeController.text.trim(),
            address: _addressController.text.trim(),
            itemNumber: _itemNumberController.text.trim(),
            itemName: inputItemName,
            hsnCode: _hsnCodeController.text.trim(),
            quantity: quantity,
            unit: _unit,
            pricePerUnit: double.parse(_priceController.text.trim()),
            totalAmount: _totalAmount,
            saleDate: _saleDate,
            remarks: _remarksController.text.trim(),
            status: _status,
            approvalStatus: newApprovalStatus,
            lastModifiedByUid: authState.user?.uid,
            lastModifiedByName: authState.user?.name,
            lastModifiedByRole: role,
            updatedAt: DateTime.now(),
          );
          await saleRepo.updateSale(companyId, updatedSale);

          if (isAccountant) {
            await ref.read(notificationServiceProvider).notifySaleApprovalRequested(
              companyId: companyId,
              saleId: updatedSale.saleId,
              saleNumber: updatedSale.saleNumber,
              itemName: updatedSale.itemName,
              customerName: updatedSale.customerName,
              totalAmount: updatedSale.totalAmount,
              userUid: authState.user?.uid ?? '',
              userName: authState.user?.name ?? 'Accountant',
              isUpdate: true,
            );
          } else {
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
        }
      } else {
        // Create Mode
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
        final autoInvoiceNumber = _invoiceNumberController.text.trim().isNotEmpty
            ? _invoiceNumberController.text.trim()
            : _generateUniqueInvoiceNumber(existingSales);

        final newSaleId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('sales').doc().id;
        final newSale = SaleModel(
          saleId: newSaleId,
          companyId: companyId,
          partyId: _selectedPartyId,
          saleNumber: generatedSaleNumber,
          invoiceNumber: autoInvoiceNumber,
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.trim(),
          partyType: _partyTypeController.text.trim(),
          vendorCode: _vendorCodeController.text.trim(),
          contactPersonName: _contactPersonNameController.text.trim(),
          email: _emailController.text.trim(),
          gstin: _gstinController.text.trim(),
          state: _stateController.text.trim(),
          stateCode: _stateCodeController.text.trim(),
          address: _addressController.text.trim(),
          itemNumber: _itemNumberController.text.trim(),
          itemName: inputItemName,
          hsnCode: _hsnCodeController.text.trim(),
          quantity: quantity,
          unit: _unit,
          pricePerUnit: double.parse(_priceController.text.trim()),
          totalAmount: _totalAmount,
          saleDate: _saleDate,
          remarks: _remarksController.text.trim(),
          status: _status,
          approvalStatus: newApprovalStatus,
          createdByUid: authState.user?.uid,
          createdByName: authState.user?.name,
          createdByRole: role,
          lastModifiedByUid: authState.user?.uid,
          lastModifiedByName: authState.user?.name,
          lastModifiedByRole: role,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await saleRepo.createSale(companyId, newSale);

        if (isAccountant) {
          await ref.read(notificationServiceProvider).notifySaleApprovalRequested(
            companyId: companyId,
            saleId: newSale.saleId,
            saleNumber: newSale.saleNumber,
            itemName: newSale.itemName,
            customerName: newSale.customerName,
            totalAmount: newSale.totalAmount,
            userUid: authState.user?.uid ?? '',
            userName: authState.user?.name ?? 'Accountant',
            isUpdate: false,
          );
        } else {
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
      }

      if (mounted) {
        final message = isAccountant
            ? 'Sale submitted for Owner approval.'
            : (widget.saleId != null ? 'Sale updated successfully.' : 'Sale logged successfully.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
