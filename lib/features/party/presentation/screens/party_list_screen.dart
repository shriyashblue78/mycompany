import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
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
    final typeFilter = ref.watch(partyTypeFilterProvider);

    final role = authState.selectedRole ?? 'Employee';
    final isOwner = role == 'Owner';
    final isMobile = ResponsiveLayout.isMobile(context);

    return partiesAsync.when(
      data: (parties) {
        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Party Master', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              elevation: 0,
              backgroundColor: theme.colorScheme.surface,
              iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
              actions: [
                if (isOwner)
                  IconButton(
                    onPressed: () => context.push('/parties/add'),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                    ),
                  ),
              ],
            ),
            drawer: const ERPDrawer(),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: TextField(
                    onChanged: (val) => ref.read(partySearchQueryProvider.notifier).state = val,
                    decoration: InputDecoration(
                      hintText: 'Search by Name, GSTIN, or Vendor Code...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: ref.watch(partySearchQueryProvider).isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => ref.read(partySearchQueryProvider.notifier).state = '',
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter Chips (All, Customer, Supplier)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All', typeFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('Customer', typeFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('Supplier', typeFilter),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: parties.isEmpty
                      ? MobileEmptyState(
                          icon: Icons.business_outlined,
                          title: 'No Parties Found',
                          subtitle: 'Manage customer and supplier master records.',
                          ctaLabel: isOwner ? 'Add Party' : null,
                          onCta: isOwner ? () => context.push('/parties/add') : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: parties.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final party = parties[i];
                            final gstinStr = party.gstin.isNotEmpty ? ' · GSTIN: ${party.gstin}' : '';

                            return MobileListTile(
                              title: party.partyName,
                              subtitle: '${party.partyType} · Phone: ${party.contactNumber}$gstinStr',
                              meta: party.state.isNotEmpty ? '${party.state} (${party.stateCode})' : '',
                              leadingIcon: party.partyType == 'Customer' ? Icons.person_rounded : Icons.store_rounded,
                              leadingColor: party.partyType == 'Customer' ? Colors.blue : Colors.orange,
                              statusLabel: party.partyType,
                              onTap: isOwner ? () => context.push('/parties/edit/${party.partyId}') : null,
                              trailing: isOwner
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => context.push('/parties/edit/${party.partyId}'),
                                          child: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _confirmDelete(context, party, authState.user?.companyId ?? ''),
                                          child: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        }

        return ResponsiveScaffold(
          appBar: AppBar(
            title: const Text('Party Master Directory'),
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
            actions: [
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(right: AppSizes.p16),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/parties/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Party'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          drawer: const ERPDrawer(),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchCard(theme),
                        const SizedBox(height: AppSizes.p20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Saved Parties (${parties.length})',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                _buildFilterChip('All', typeFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip('Customer', typeFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip('Supplier', typeFilter),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p12),
                        parties.isEmpty
                            ? EmptyStateWidget(
                                icon: Icons.business_outlined,
                                title: 'No Party Master Records',
                                description: 'Add and manage Customer and Supplier master records for quick invoicing.',
                                ctaLabel: isOwner ? 'Add Party' : null,
                                onCtaPressed: isOwner ? () => context.push('/parties/add') : null,
                              )
                            : _buildPartyList(parties, isOwner, authState.user?.companyId ?? '', theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => ResponsiveScaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildFilterChip(String label, String currentFilter) {
    final isSelected = currentFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(partyTypeFilterProvider.notifier).state = label;
        }
      },
    );
  }

  Widget _buildSearchCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: TextField(
          onChanged: (val) => ref.read(partySearchQueryProvider.notifier).state = val,
          decoration: InputDecoration(
            hintText: 'Search by Party Name, GSTIN, or Vendor Code...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ref.watch(partySearchQueryProvider).isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => ref.read(partySearchQueryProvider.notifier).state = '',
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyList(List<PartyModel> parties, bool isOwner, String companyId, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parties.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final party = parties[index];
        final isCustomer = party.partyType == 'Customer';

        return Card(
          key: ValueKey(party.partyId),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(color: theme.dividerColor.withAlpha(50)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isCustomer ? Icons.person_rounded : Icons.store_rounded, color: isCustomer ? Colors.blue : Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(party.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCustomer ? Colors.blue.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isCustomer ? Colors.blue.shade200 : Colors.orange.shade200),
                          ),
                          child: Text(
                            party.partyType,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCustomer ? Colors.blue.shade800 : Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                    if (isOwner)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            onPressed: () => context.push('/parties/edit/${party.partyId}'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                            onPressed: () => _confirmDelete(context, party, companyId),
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Contact: ${party.contactNumber}${party.contactPersonName.isNotEmpty ? " (${party.contactPersonName})" : ""}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (party.gstin.isNotEmpty) Text('GSTIN: ${party.gstin}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text([
                  if (party.vendorCode.isNotEmpty) 'Vendor Code: ${party.vendorCode}',
                  if (party.state.isNotEmpty) 'State: ${party.state} (${party.stateCode})',
                  if (party.email.isNotEmpty) 'Email: ${party.email}',
                ].join(' · ')),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, PartyModel party, String companyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Party Record'),
        content: Text('Are you sure you want to delete "${party.partyName}" from Party Master?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(partyRepositoryProvider).deleteParty(companyId, party.partyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Party record deleted successfully.')),
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
