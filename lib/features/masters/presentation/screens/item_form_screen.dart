import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/group_model.dart';
import '../../domain/models/item_model.dart';
import '../../domain/models/unit_model.dart';
import '../providers/category_provider.dart';
import '../providers/group_provider.dart';
import '../providers/item_provider.dart';
import '../providers/unit_provider.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  final String? itemId;
  const ItemFormScreen({super.key, this.itemId});

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _itemNoController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final _drawingNoController = TextEditingController();
  final _previousNoController = TextEditingController();
  final _hsnSacController = TextEditingController();
  final _unitRateController = TextEditingController(text: '0.0');
  final _finishRateController = TextEditingController(text: '0.0');
  final _netWeightController = TextEditingController(text: '0.0');
  final _storeLocationController = TextEditingController();
  final _minimumLevelController = TextEditingController(text: '0.0');
  final _materialSpecController = TextEditingController();
  final _qtyPerPackController = TextEditingController(text: '1.0');

  String? _selectedCategory;
  String? _selectedGroup;
  String? _selectedUnit;
  bool _isFinishedItem = false;

  bool _saving = false;
  bool _initialized = false;
  ItemModel? _existingItem;
  String? _errorMessage;

  @override
  void dispose() {
    _itemNoController.dispose();
    _itemDescriptionController.dispose();
    _drawingNoController.dispose();
    _previousNoController.dispose();
    _hsnSacController.dispose();
    _unitRateController.dispose();
    _finishRateController.dispose();
    _netWeightController.dispose();
    _storeLocationController.dispose();
    _minimumLevelController.dispose();
    _materialSpecController.dispose();
    _qtyPerPackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.itemId != null;
    final isMobile = ResponsiveLayout.isMobile(context);

    final authState = ref.watch(authProvider);
    final companyId = authState.user?.companyId ?? '';
    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';

    if (!canManage) {
      return ResponsiveScaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Access Denied. Only Owner or Accountant can manage Item Master.'),
        ),
      );
    }

    final categoriesAsync = ref.watch(companyCategoriesStreamProvider);
    final groupsAsync = ref.watch(companyGroupsStreamProvider);
    final unitsAsync = ref.watch(companyUnitsStreamProvider);

    if (isEdit && !_initialized) {
      final itemDetailsAsync = ref.watch(itemDetailsStreamProvider(widget.itemId!));
      return itemDetailsAsync.when(
        data: (item) {
          if (item == null) {
            return ResponsiveScaffold(
              appBar: AppBar(title: const Text('Item Not Found')),
              body: const Center(child: Text('The requested Item record could not be found.')),
            );
          }
          _existingItem = item;
          _itemNoController.text = item.itemNo;
          _itemDescriptionController.text = item.itemDescription;
          _selectedCategory = item.category.isNotEmpty ? item.category : null;
          _selectedGroup = (item.underGroup != null && item.underGroup!.isNotEmpty) ? item.underGroup : null;
          _drawingNoController.text = item.drawingNo ?? '';
          _previousNoController.text = item.previousNo ?? '';
          _selectedUnit = item.stockUnit.isNotEmpty ? item.stockUnit : null;
          _hsnSacController.text = item.hsnSac ?? '';
          _unitRateController.text = item.unitRate > 0 ? item.unitRate.toString() : '0.0';
          _finishRateController.text = item.finishRate > 0 ? item.finishRate.toString() : '0.0';
          _netWeightController.text = item.netWeight > 0 ? item.netWeight.toString() : '0.0';
          _storeLocationController.text = item.storeLocation ?? '';
          _minimumLevelController.text = item.minimumLevel > 0 ? item.minimumLevel.toString() : '0.0';
          _isFinishedItem = item.isFinishedItem;
          _materialSpecController.text = item.materialSpecification ?? '';
          _qtyPerPackController.text = item.qtyPerPack > 0 ? item.qtyPerPack.toString() : '1.0';
          _initialized = true;

          return _buildFormScaffold(context, theme, isDark, isEdit, isMobile, companyId, categoriesAsync, groupsAsync, unitsAsync);
        },
        loading: () => ResponsiveScaffold(
          appBar: AppBar(title: const Text('Loading Item...')),
          body: const Center(child: CardListSkeleton()),
        ),
        error: (err, _) => ResponsiveScaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(child: Text('Error loading item: $err')),
        ),
      );
    }

    return _buildFormScaffold(context, theme, isDark, isEdit, isMobile, companyId, categoriesAsync, groupsAsync, unitsAsync);
  }

  Widget _buildFormScaffold(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isEdit,
    bool isMobile,
    String companyId,
    AsyncValue<List<CategoryModel>> categoriesAsync,
    AsyncValue<List<GroupModel>> groupsAsync,
    AsyncValue<List<UnitModel>> unitsAsync,
  ) {
    final categories = categoriesAsync.valueOrNull ?? <CategoryModel>[];
    final groups = groupsAsync.valueOrNull ?? <GroupModel>[];
    final units = unitsAsync.valueOrNull ?? <UnitModel>[];

    // Fallback if masters empty: provide reasonable defaults
    final categoryList = <String>[];
    for (final c in categories) {
      if (c.categoryName.isNotEmpty && !categoryList.contains(c.categoryName)) {
        categoryList.add(c.categoryName);
      }
    }
    if (categoryList.isEmpty) {
      categoryList.addAll(['Raw Material', 'Finished Goods', 'Consumable', 'Hardware', 'Components']);
    }
    if (_selectedCategory == null && categoryList.isNotEmpty) {
      _selectedCategory = categoryList.first;
    }

    final unitList = <String>[];
    for (final u in units) {
      if (u.unit.isNotEmpty && !unitList.contains(u.unit)) {
        unitList.add(u.unit);
      }
    }
    if (unitList.isEmpty) {
      unitList.addAll(['Nos', 'KG', 'MTR', 'LTR', 'PCS', 'SET']);
    }
    if (_selectedUnit == null && unitList.isNotEmpty) {
      _selectedUnit = unitList.first;
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Item Master' : 'New Item Master',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Banner if present
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSizes.p12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.p16),
                  ],

                  // Card 1: Core Item Identity
                  ResponsiveCard(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, 'Item Identity & Classification', Icons.badge_outlined),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _itemNoController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Item / Part No. *',
                                hintText: 'e.g. PN-10023, BOLT-M8',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Item / Part Number is required';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _itemDescriptionController,
                              decoration: InputDecoration(
                                labelText: 'Item Name / Description *',
                                hintText: 'e.g. Hexagonal Bolt M8 x 40mm',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Item Name / Description is required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            DropdownButtonFormField<String>(
                              value: categoryList.contains(_selectedCategory) ? _selectedCategory : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Item Category *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              items: [
                                for (final cat in categoryList)
                                  DropdownMenuItem<String>(value: cat, child: Text(cat)),
                              ],
                              onChanged: (val) => setState(() => _selectedCategory = val),
                              validator: (val) => val == null || val.isEmpty ? 'Category is required' : null,
                            ),
                            DropdownButtonFormField<String?>(
                              value: (groups.any((g) => g.groupName == _selectedGroup)) ? _selectedGroup : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Under Group',
                                helperText: 'Optional hierarchy group',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('None (Primary)')),
                                for (final g in groups)
                                  DropdownMenuItem<String?>(
                                    value: g.groupName,
                                    child: Text(g.groupName),
                                  ),
                              ],
                              onChanged: (val) => setState(() => _selectedGroup = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Card 2: Technical Specifications & Codes
                  ResponsiveCard(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, 'Technical Specifications', Icons.precision_manufacturing_outlined),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _drawingNoController,
                              decoration: InputDecoration(
                                labelText: 'Drawing No.',
                                hintText: 'e.g. DWG-2026-A1',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                            TextFormField(
                              controller: _previousNoController,
                              decoration: InputDecoration(
                                labelText: 'Previous No.',
                                hintText: 'e.g. Legacy part number',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            DropdownButtonFormField<String>(
                              value: unitList.contains(_selectedUnit) ? _selectedUnit : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Stock Unit *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              items: [
                                for (final u in unitList)
                                  DropdownMenuItem<String>(value: u, child: Text(u)),
                              ],
                              onChanged: (val) => setState(() => _selectedUnit = val),
                              validator: (val) => val == null || val.isEmpty ? 'Stock unit is required' : null,
                            ),
                            TextFormField(
                              controller: _hsnSacController,
                              decoration: InputDecoration(
                                labelText: 'HSN / SAC Code',
                                hintText: 'e.g. 7318, 8471',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          controller: _materialSpecController,
                          decoration: InputDecoration(
                            labelText: 'Material Specification',
                            hintText: 'e.g. SS304, MS Bright Bar, Aluminum 6061-T6',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Card 3: Rates & Logistics
                  ResponsiveCard(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, 'Valuation, Inventory & Packaging', Icons.inventory_outlined),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _unitRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Unit Rate (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validatePositiveNumber,
                            ),
                            TextFormField(
                              controller: _finishRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Finish Rate (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validatePositiveNumber,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _netWeightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Net Weight (Kg)',
                                suffixText: 'kg',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validatePositiveNumber,
                            ),
                            TextFormField(
                              controller: _storeLocationController,
                              decoration: InputDecoration(
                                labelText: 'Store Location / Bin',
                                hintText: 'e.g. Rack B-3, Bin 12',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        ResponsiveFormRow(
                          children: [
                            TextFormField(
                              controller: _minimumLevelController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Minimum Stock Level',
                                helperText: 'Alert threshold for reordering',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validatePositiveNumber,
                            ),
                            TextFormField(
                              controller: _qtyPerPackController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Qty / Pack',
                                helperText: 'Standard packing quantity',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                              ),
                              validator: _validatePositiveNumber,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Finished Item?', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Designate whether this item is a finished commercial product ready for dispatch/sales.'),
                          value: _isFinishedItem,
                          activeColor: AppColors.primaryLight,
                          onChanged: (val) => setState(() => _isFinishedItem = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.p24),

                  // Form Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSizes.p16),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : () => _submitForm(companyId, isEdit),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(isEdit ? 'Update Item' : 'Save Item'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String? _validatePositiveNumber(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final num = double.tryParse(val.trim());
    if (num == null) return 'Must be a valid number';
    if (num < 0) return 'Cannot be negative';
    return null;
  }

  Future<void> _submitForm(String companyId, bool isEdit) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final repo = ref.read(itemRepositoryProvider);
    final itemNo = _itemNoController.text.trim();
    final itemDesc = _itemDescriptionController.text.trim();

    try {
      // 1. Prevent duplicate Item No. within the company
      final isTaken = await repo.isItemNoTaken(
        companyId,
        itemNo,
        excludeItemId: isEdit ? widget.itemId : null,
      );

      if (isTaken) {
        setState(() {
          _saving = false;
          _errorMessage = 'An item with part number "$itemNo" already exists in this company.';
        });
        return;
      }

      final unitRate = double.tryParse(_unitRateController.text.trim()) ?? 0.0;
      final finishRate = double.tryParse(_finishRateController.text.trim()) ?? 0.0;
      final netWeight = double.tryParse(_netWeightController.text.trim()) ?? 0.0;
      final minLevel = double.tryParse(_minimumLevelController.text.trim()) ?? 0.0;
      final qtyPack = double.tryParse(_qtyPerPackController.text.trim()) ?? 1.0;

      if (isEdit && _existingItem != null) {
        final updated = _existingItem!.copyWith(
          itemNo: itemNo,
          itemDescription: itemDesc,
          category: _selectedCategory ?? 'General',
          underGroup: _selectedGroup,
          drawingNo: _drawingNoController.text.trim(),
          previousNo: _previousNoController.text.trim(),
          stockUnit: _selectedUnit ?? 'Nos',
          hsnSac: _hsnSacController.text.trim(),
          unitRate: unitRate,
          finishRate: finishRate,
          netWeight: netWeight,
          storeLocation: _storeLocationController.text.trim(),
          minimumLevel: minLevel,
          isFinishedItem: _isFinishedItem,
          materialSpecification: _materialSpecController.text.trim(),
          qtyPerPack: qtyPack,
        );
        await repo.updateItem(companyId, updated);
      } else {
        final newItem = ItemModel(
          itemId: '',
          companyId: companyId,
          itemNo: itemNo,
          itemDescription: itemDesc,
          category: _selectedCategory ?? 'General',
          underGroup: _selectedGroup,
          drawingNo: _drawingNoController.text.trim(),
          previousNo: _previousNoController.text.trim(),
          stockUnit: _selectedUnit ?? 'Nos',
          hsnSac: _hsnSacController.text.trim(),
          unitRate: unitRate,
          finishRate: finishRate,
          netWeight: netWeight,
          storeLocation: _storeLocationController.text.trim(),
          minimumLevel: minLevel,
          isFinishedItem: _isFinishedItem,
          materialSpecification: _materialSpecController.text.trim(),
          qtyPerPack: qtyPack,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createItem(companyId, newItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Item updated successfully' : 'Item created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = 'Error saving item: $e';
      });
    }
  }
}
