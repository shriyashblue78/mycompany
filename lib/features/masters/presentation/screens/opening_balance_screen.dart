import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/group_model.dart';
import '../../domain/models/item_model.dart';
import '../../domain/repositories/item_repository.dart';
import '../providers/group_provider.dart';
import '../providers/item_provider.dart';

class OpeningBalanceScreen extends ConsumerStatefulWidget {
  const OpeningBalanceScreen({super.key});

  @override
  ConsumerState<OpeningBalanceScreen> createState() => _OpeningBalanceScreenState();
}

class _ItemRowState {
  final ItemModel item;
  final TextEditingController storeWipController;
  final TextEditingController rateController;
  final TextEditingController finishQtyController;
  final TextEditingController finishRateController;
  final bool isAlreadyRecorded;

  _ItemRowState({
    required this.item,
    required this.storeWipController,
    required this.rateController,
    required this.finishQtyController,
    required this.finishRateController,
    required this.isAlreadyRecorded,
  });

  void dispose() {
    storeWipController.dispose();
    rateController.dispose();
    finishQtyController.dispose();
    finishRateController.dispose();
  }
}

class _OpeningBalanceScreenState extends ConsumerState<OpeningBalanceScreen> {
  // Step 1: Selected Group in dropdown
  String? _selectedGroupId;
  GroupModel? _selectedGroup;

  // Step 2: Confirmed group when Continue is clicked
  GroupModel? _confirmedGroup;
  List<_ItemRowState> _rowStates = [];
  bool _isSaving = false;
  String? _statusMessage;
  String _itemSearchQuery = '';

  @override
  void dispose() {
    _clearRowStates();
    super.dispose();
  }

  void _clearRowStates() {
    for (final r in _rowStates) {
      r.dispose();
    }
    _rowStates = [];
  }

  void _onContinue(List<ItemModel> allItems) {
    if (_selectedGroup == null) return;

    final group = _selectedGroup!;
    final groupNameLower = group.groupName.trim().toLowerCase();
    final associatedItems = allItems.where((i) {
      final itemGroup = (i.underGroup ?? '').trim().toLowerCase();
      return itemGroup == groupNameLower;
    }).toList();

    _clearRowStates();

    _rowStates = associatedItems.map((item) {
      final isRecorded = item.hasOpeningBalance;

      // Store/WIP Qty
      final storeWipQtyText = item.openingBalance > 0
          ? (item.openingBalance % 1 == 0 ? item.openingBalance.toInt().toString() : item.openingBalance.toString())
          : '';

      // Unit Rate
      final rateText = item.unitRate > 0 ? item.unitRate.toString() : '';

      // Finish Qty & Finish Rate
      final finishQtyText = (item.isFinishedItem && item.openingBalance > 0)
          ? (item.openingBalance % 1 == 0 ? item.openingBalance.toInt().toString() : item.openingBalance.toString())
          : '';
      final finishRateText = item.finishRate > 0 ? item.finishRate.toString() : '';

      return _ItemRowState(
        item: item,
        storeWipController: TextEditingController(text: storeWipQtyText),
        rateController: TextEditingController(text: rateText),
        finishQtyController: TextEditingController(text: finishQtyText),
        finishRateController: TextEditingController(text: finishRateText),
        isAlreadyRecorded: isRecorded,
      );
    }).toList();

    setState(() {
      _confirmedGroup = group;
      _statusMessage = null;
      _itemSearchQuery = '';
    });
  }

  void _onCancel() {
    setState(() {
      _confirmedGroup = null;
      _statusMessage = null;
      _itemSearchQuery = '';
    });
    _clearRowStates();
  }

  Future<void> _handleSave(String companyId) async {
    final pendingRows = _rowStates.where((r) => !r.isAlreadyRecorded).toList();
    if (pendingRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items are already recorded or no items to save.')),
      );
      setState(() => _confirmedGroup = null);
      _clearRowStates();
      return;
    }

    final entriesToSave = <OpeningBalanceEntryItem>[];

    for (final row in pendingRows) {
      final storeWipStr = row.storeWipController.text.trim();
      final rateStr = row.rateController.text.trim();
      final finishQtyStr = row.finishQtyController.text.trim();
      final finishRateStr = row.finishRateController.text.trim();

      // If user left everything blank for an item, skip it unless required
      if (storeWipStr.isEmpty && rateStr.isEmpty && finishQtyStr.isEmpty && finishRateStr.isEmpty) {
        continue;
      }

      final storeWipQty = storeWipStr.isEmpty ? 0.0 : double.tryParse(storeWipStr);
      if (storeWipQty == null || storeWipQty < 0) {
        setState(() {
          _statusMessage = 'Please enter a valid non-negative number for Store/WIP in "${row.item.itemDescription}".';
        });
        return;
      }

      final rate = rateStr.isEmpty ? 0.0 : double.tryParse(rateStr);
      if (rate == null || rate < 0) {
        setState(() {
          _statusMessage = 'Please enter a valid non-negative Rate in "${row.item.itemDescription}".';
        });
        return;
      }

      final finishQty = finishQtyStr.isEmpty ? 0.0 : double.tryParse(finishQtyStr);
      if (finishQty == null || finishQty < 0) {
        setState(() {
          _statusMessage = 'Please enter a valid non-negative number for Finish in "${row.item.itemDescription}".';
        });
        return;
      }

      final finishRate = finishRateStr.isEmpty ? 0.0 : double.tryParse(finishRateStr);
      if (finishRate == null || finishRate < 0) {
        setState(() {
          _statusMessage = 'Please enter a valid non-negative Finish Rate in "${row.item.itemDescription}".';
        });
        return;
      }

      // Total opening balance quantity for the item
      final effectiveOpeningBalance = storeWipQty > 0 ? storeWipQty : finishQty;

      entriesToSave.add(
        OpeningBalanceEntryItem(
          itemId: row.item.itemId,
          itemDescription: row.item.itemDescription,
          partNo: row.item.itemNo,
          storeOrWip: storeWipQty > 0 ? 'Store' : 'Finish',
          openingBalance: effectiveOpeningBalance,
          unitRate: rate,
          finishRate: finishRate,
        ),
      );
    }

    if (entriesToSave.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter values for at least one item before saving.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final count = await itemRepo.saveOpeningBalances(companyId, entriesToSave);

      ref.invalidate(companyItemsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening balance successfully saved for $count item(s).'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _isSaving = false;
          _confirmedGroup = null;
          _selectedGroupId = null;
          _selectedGroup = null;
        });
        _clearRowStates();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Failed to save opening balances: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(companyGroupsStreamProvider);
    final itemsAsync = ref.watch(companyItemsStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final allGroups = groupsAsync.valueOrNull ?? [];
    final allItems = itemsAsync.valueOrNull ?? [];

    final appBar = AppBar(
      title: const Text(
        'Opening Balance Entry',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
      leading: _confirmedGroup != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back to Group Selection',
              onPressed: _onCancel,
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSizes.p16),
          child: TextButton.icon(
            onPressed: () => context.push('/masters/groups'),
            icon: const Icon(Icons.folder_special_rounded, size: 18),
            label: const Text('Group Master'),
          ),
        ),
      ],
    );

    return ResponsiveScaffold(
      appBar: appBar,
      drawer: const ERPDrawer(),
      body: _confirmedGroup == null
          ? _buildStep1SelectGroup(
              context: context,
              allGroups: allGroups,
              allItems: allItems,
              groupsAsync: groupsAsync,
              theme: theme,
              isDark: isDark,
              isMobile: isMobile,
            )
          : _buildStep2OpeningBalanceForm(
              context: context,
              group: _confirmedGroup!,
              companyId: companyId,
              canManage: canManage,
              theme: theme,
              isDark: isDark,
              isMobile: isMobile,
            ),
    );
  }

  /// Step 1: Select Group Name and click Continue
  Widget _buildStep1SelectGroup({
    required BuildContext context,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
    required AsyncValue<List<GroupModel>> groupsAsync,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step 1 Header Card
              Container(
                padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF10B981),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Step 1: Select Group',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select a Group Name from existing Group Master records to enter item opening stock and rates.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Group Name dropdown label
                    Text(
                      'Group Name *',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),

                    groupsAsync.when(
                      data: (groups) {
                        if (groups.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 20, color: Colors.grey),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'No groups found in Group Master. Please create item groups first.',
                                    style: TextStyle(fontSize: 13.5, color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/masters/groups'),
                                  child: const Text('Go to Group Master'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedGroupId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  hintText: 'Select Group Name...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                  ),
                                  prefixIcon: const Icon(Icons.folder_special_rounded, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                                items: [
                                  for (final g in groups)
                                    DropdownMenuItem<String>(
                                      value: g.groupId,
                                      child: Text(
                                        (g.parentGroupName != null && g.parentGroupName!.isNotEmpty)
                                            ? '${g.groupName} (under ${g.parentGroupName})'
                                            : g.groupName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedGroupId = val;
                                    _selectedGroup = groups.where((g) => g.groupId == val).firstOrNull;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Continue button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: _selectedGroup != null
                                        ? () => _onContinue(allItems)
                                        : null,
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                    label: const Text(
                                      'Continue to Opening Balance',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryLight,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                      disabledForegroundColor: Colors.grey.shade500,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => Text(
                        'Error loading groups: $err',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.p24),

              // Available Groups quick-pick list
              if (allGroups.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            Text(
                              'Existing Groups (${allGroups.length})',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1F2937),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Select above or click a group below',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: allGroups.length,
                        separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderColor),
                        itemBuilder: (context, idx) {
                          final g = allGroups[idx];
                          final isSelected = _selectedGroupId == g.groupId;
                          final gItems = allItems.where((i) =>
                              (i.underGroup ?? '').trim().toLowerCase() ==
                              g.groupName.trim().toLowerCase()).toList();

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: AppColors.primaryLight.withOpacity(0.08),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 16),
                            ),
                            title: Text(
                              g.groupName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: g.parentGroupName != null && g.parentGroupName!.isNotEmpty
                                ? Text(
                                    '↳ Under: ${g.parentGroupName}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${gItems.length} items',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedGroupId = g.groupId;
                                _selectedGroup = g;
                              });
                              _onContinue(allItems);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: Editable spreadsheet-style Opening Balance Entry Form
  /// Table Columns (exactly as reference):
  /// 1. Item Description
  /// 2. Matl No.
  /// 3. Store/WIP
  /// 4. Rate
  /// 5. Finish
  /// 6. Rate
  Widget _buildStep2OpeningBalanceForm({
    required BuildContext context,
    required GroupModel group,
    required String companyId,
    required bool canManage,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final headerBgColor = isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    final filteredRows = _rowStates.where((r) {
      if (_itemSearchQuery.isEmpty) return true;
      final q = _itemSearchQuery.toLowerCase();
      return r.item.itemDescription.toLowerCase().contains(q) ||
          r.item.itemNo.toLowerCase().contains(q);
    }).toList();

    final pendingCount = _rowStates.where((r) => !r.isAlreadyRecorded).length;
    final recordedCount = _rowStates.where((r) => r.isAlreadyRecorded).length;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
        vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selected Group Info Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: isMobile ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Group Name: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  group.groupName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (group.parentGroupName != null && group.parentGroupName!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(under ${group.parentGroupName})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Items: ${_rowStates.length}  •  Pending: $pendingCount  •  Recorded: $recordedCount',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Change Group Action
                    OutlinedButton.icon(
                      onPressed: _onCancel,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Change Group', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.p12),

              // Search Filter Bar
              if (_rowStates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            onChanged: (val) => setState(() => _itemSearchQuery = val),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search items by description or matl no...',
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              suffixIcon: _itemSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () => setState(() => _itemSearchQuery = ''),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${filteredRows.length} items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_statusMessage != null) ...[
                const SizedBox(height: AppSizes.p12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.p12),

              // Spreadsheet Table Card
              Container(
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _rowStates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No items assigned to group "${group.groupName}".',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please assign items to this group in Item Master or Update Item Group.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _onCancel,
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Back to Group Selection'),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Ensure horizontal scrolling on mobile with minimum width
                          const double minTableWidth = 860;
                          final double tableWidth = constraints.maxWidth > minTableWidth
                              ? constraints.maxWidth
                              : minTableWidth;

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Table Header with exact columns:
                                  // 1. Item Description | 2. Matl No. | 3. Store/WIP | 4. Rate | 5. Finish | 6. Rate
                                  Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: headerBgColor,
                                      border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell('Item Description', flex: 4, minWidth: 240, isDark: isDark),
                                        _buildHeaderCell('Matl No.', width: 150, isDark: isDark),
                                        _buildHeaderCell('Store/WIP', width: 130, isDark: isDark),
                                        _buildHeaderCell('Rate', width: 120, isDark: isDark),
                                        _buildHeaderCell('Finish', width: 120, isDark: isDark),
                                        _buildHeaderCell('Rate', width: 120, isDark: isDark),
                                      ],
                                    ),
                                  ),

                                  // Table Rows
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredRows.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderColor),
                                    itemBuilder: (context, index) {
                                      final row = filteredRows[index];
                                      final isLocked = row.isAlreadyRecorded;

                                      return Container(
                                        color: isLocked
                                            ? (isDark ? Colors.white.withOpacity(0.02) : Colors.grey.withOpacity(0.04))
                                            : null,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // 1. Item Description
                                            Expanded(
                                              flex: 4,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(minWidth: 240),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      row.item.itemDescription,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13.5,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Unit: ${row.item.stockUnit} • Category: ${row.item.category}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // 2. Matl No.
                                            SizedBox(
                                              width: 150,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  row.item.itemNo,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // 3. Store/WIP (Qty input)
                                            SizedBox(
                                              width: 130,
                                              child: SizedBox(
                                                height: 38,
                                                child: TextFormField(
                                                  controller: row.storeWipController,
                                                  enabled: !isLocked,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  decoration: InputDecoration(
                                                    hintText: '0',
                                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // 4. Rate (for Store/WIP)
                                            SizedBox(
                                              width: 120,
                                              child: SizedBox(
                                                height: 38,
                                                child: TextFormField(
                                                  controller: row.rateController,
                                                  enabled: !isLocked,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: const TextStyle(fontSize: 13),
                                                  decoration: InputDecoration(
                                                    prefixText: '₹ ',
                                                    prefixStyle: const TextStyle(fontSize: 11),
                                                    hintText: '0.00',
                                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // 5. Finish (Qty input)
                                            SizedBox(
                                              width: 120,
                                              child: SizedBox(
                                                height: 38,
                                                child: TextFormField(
                                                  controller: row.finishQtyController,
                                                  enabled: !isLocked,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  decoration: InputDecoration(
                                                    hintText: '0',
                                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // 6. Rate (for Finish)
                                            SizedBox(
                                              width: 120,
                                              child: SizedBox(
                                                height: 38,
                                                child: TextFormField(
                                                  controller: row.finishRateController,
                                                  enabled: !isLocked,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: const TextStyle(fontSize: 13),
                                                  decoration: InputDecoration(
                                                    prefixText: '₹ ',
                                                    prefixStyle: const TextStyle(fontSize: 11),
                                                    hintText: '0.00',
                                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: AppSizes.p16),

              // Bottom Actions Bar (Cancel & Save)
              if (_rowStates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        pendingCount > 0
                            ? '$pendingCount item(s) pending opening balance'
                            : 'All items already recorded',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Cancel Button
                      OutlinedButton(
                        onPressed: _isSaving ? null : _onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      // Save Button
                      if (canManage)
                        ElevatedButton.icon(
                          onPressed: (_isSaving || pendingCount == 0)
                              ? null
                              : () => _handleSave(companyId),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    double? width,
    int? flex,
    double? minWidth,
    Alignment alignment = Alignment.centerLeft,
    required bool isDark,
  }) {
    final cell = Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1F2937),
          letterSpacing: 0.2,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return Expanded(
      flex: flex ?? 1,
      child: minWidth != null
          ? ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: cell,
            )
          : cell,
    );
  }
}
