import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/party_model.dart';
import '../providers/party_provider.dart';

class PartyListScreen extends ConsumerStatefulWidget {
  const PartyListScreen({super.key});

  @override
  ConsumerState<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends ConsumerState<PartyListScreen> {
  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(filteredPartiesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeFilter = ref.watch(partyTypeFilterProvider);
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final isOwner = role == 'Owner';
    final companyId = authState.user?.companyId ?? '';

    final appBar = AppBar(
      title: const Text(
        'Party Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return partiesAsync.when(
      data: (parties) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyPartiesStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
              vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderBar(
                      context: context,
                      isOwner: isOwner,
                      typeFilter: typeFilter,
                      theme: theme,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: parties.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (parties.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.business_outlined,
                        title: 'No Parties Found',
                        description: ref.watch(partySearchQueryProvider).isNotEmpty
                            ? 'No parties match your search query.'
                            : 'Add customer and supplier accounts for invoicing and purchase orders.',
                      )
                    else
                      _buildPartyDataTable(
                        context: context,
                        parties: parties,
                        isOwner: isOwner,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                        isMobile: isMobile,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        return ResponsiveScaffold(
          appBar: appBar,
          drawer: const ERPDrawer(),
          body: body,
        );
      },
      loading: () => ResponsiveScaffold(
        appBar: appBar,
        drawer: const ERPDrawer(),
        body: const Center(child: CardListSkeleton()),
      ),
      error: (err, _) => ResponsiveScaffold(
        appBar: appBar,
        drawer: const ERPDrawer(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('Error loading parties: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyPartiesStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar({
    required BuildContext context,
    required bool isOwner,
    required String typeFilter,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
    required int count,
  }) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
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
          // Search input box
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 380,
              minWidth: isMobile ? double.infinity : 260,
            ),
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: (val) => ref.read(partySearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Name, GSTIN, or Code...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(partySearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(partySearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.accentDark : AppColors.primaryLight,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Type Filter Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTypeFilterChip('All', typeFilter, isDark),
              _buildTypeFilterChip('Customer', typeFilter, isDark),
              _buildTypeFilterChip('Supplier', typeFilter, isDark),
            ],
          ),

          // Total count badge and New Party action button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'Total: $count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/parties/add'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Party',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(String label, String currentFilter, bool isDark) {
    final isSelected = currentFilter == label;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => ref.read(partyTypeFilterProvider.notifier).state = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
              : (isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyDataTable({
    required BuildContext context,
    required List<PartyModel> parties,
    required bool isOwner,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final headerBgColor = isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double minTableWidth = 960;
          final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spreadsheet Column Headers
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: headerBgColor,
                      border: Border(
                        bottom: BorderSide(color: borderColor, width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Sr.', width: 65, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Party Name', flex: 4, minWidth: 200, isDark: isDark),
                        _buildHeaderCell('Type', flex: 2, minWidth: 110, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('GSTIN', flex: 2, minWidth: 140, isDark: isDark),
                        _buildHeaderCell('Contact / Phone', flex: 3, minWidth: 160, isDark: isDark),
                        _buildHeaderCell('State', flex: 2, minWidth: 120, isDark: isDark),
                        _buildHeaderCell('Actions', width: 135, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: parties.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final party = parties[index];
                      return _buildTableRow(
                        context: context,
                        index: index,
                        party: party,
                        isOwner: isOwner,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
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

  Widget _buildTableRow({
    required BuildContext context,
    required int index,
    required PartyModel party,
    required bool isOwner,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final zebraColor = index.isOdd
        ? (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FAFB))
        : Colors.transparent;
    final isCustomer = party.partyType == 'Customer';

    return Material(
      color: zebraColor,
      child: InkWell(
        hoverColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
        onTap: () => _viewPartyDetails(context, party),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              // Sr. No.
              SizedBox(
                width: 65,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),

              // Party Name + Vendor Code
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: (isCustomer ? const Color(0xFF2563EB) : const Color(0xFFF59E0B))
                              .withOpacity(isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isCustomer ? Icons.person_rounded : Icons.store_rounded,
                          size: 16,
                          color: isCustomer ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              party.partyName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (party.vendorCode.isNotEmpty)
                              Text(
                                'Code: ${party.vendorCode}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Type badge
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isCustomer
                          ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF78350F).withOpacity(0.5) : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isCustomer
                            ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                            : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A)),
                      ),
                    ),
                    child: Text(
                      party.partyType,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isCustomer
                            ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                            : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                      ),
                    ),
                  ),
                ),
              ),

              // GSTIN
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: party.gstin.isNotEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? Colors.grey.shade700 : const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Text(
                              party.gstin,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          '—',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          ),
                        ),
                ),
              ),

              // Contact
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        party.contactNumber.isNotEmpty ? party.contactNumber : '—',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (party.contactPersonName.isNotEmpty)
                        Text(
                          party.contactPersonName,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),

              // State
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    party.state.isNotEmpty
                        ? (party.stateCode.isNotEmpty ? '${party.state} (${party.stateCode})' : party.state)
                        : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Actions (View, Edit, Delete)
              SizedBox(
                width: 135,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSubtleActionButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'View Details',
                      color: const Color(0xFF2563EB),
                      hoverColor: const Color(0xFF2563EB).withOpacity(0.12),
                      onPressed: () => _viewPartyDetails(context, party),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Party',
                        color: const Color(0xFF059669),
                        hoverColor: const Color(0xFF059669).withOpacity(0.12),
                        onPressed: () => context.push('/parties/edit/${party.partyId}'),
                      ),
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete Party',
                        color: const Color(0xFFDC2626),
                        hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                        onPressed: () => _confirmDelete(context, party, companyId),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color hoverColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: hoverColor,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  void _viewPartyDetails(BuildContext context, PartyModel party) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (party.partyType == 'Customer' ? Colors.blue : Colors.orange).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                party.partyType == 'Customer' ? Icons.person_rounded : Icons.store_rounded,
                color: party.partyType == 'Customer' ? Colors.blue : Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                party.partyName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Party Type', party.partyType),
              if (party.vendorCode.isNotEmpty) _detailRow('Vendor Code', party.vendorCode),
              if (party.gstin.isNotEmpty) _detailRow('GSTIN', party.gstin),
              if (party.contactPersonName.isNotEmpty) _detailRow('Contact Person', party.contactPersonName),
              if (party.contactNumber.isNotEmpty) _detailRow('Phone', party.contactNumber),
              if (party.email.isNotEmpty) _detailRow('Email', party.email),
              if (party.state.isNotEmpty) _detailRow('State', '${party.state} (${party.stateCode})'),
              if (party.address.isNotEmpty) _detailRow('Address', party.address),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PartyModel party, String companyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Party Record'),
        content: Text('Are you sure you want to permanently delete "${party.partyName}" from Party Master?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(partyRepositoryProvider).deleteParty(companyId, party.partyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Party record deleted successfully.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting party: $e')),
          );
        }
      }
    }
  }
}
