import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/inward_outward_repository_impl.dart';
import '../../domain/models/inward_outward_model.dart';
import '../providers/inward_outward_provider.dart';

class InwardOutwardListScreen extends ConsumerStatefulWidget {
  const InwardOutwardListScreen({super.key});

  @override
  ConsumerState<InwardOutwardListScreen> createState() => _InwardOutwardListScreenState();
}

class _InwardOutwardListScreenState extends ConsumerState<InwardOutwardListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Inward', 'Outward'

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(inwardOutwardListStreamProvider);
    final stats = ref.watch(inwardOutwardStatsProvider);
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final isOwner = role == 'Owner';
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Inward / Outward Management'),
        elevation: 0,
      ),
      drawer: const ERPDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inward-outward/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Inward / Outward'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading records: $err')),
        data: (records) {
          final filtered = records.where((r) {
            final matchesFilter = _selectedFilter == 'All' ||
                r.direction.toLowerCase() == _selectedFilter.toLowerCase();
            
            final q = _searchQuery.toLowerCase();
            final matchesSearch = q.isEmpty ||
                r.companyName.toLowerCase().contains(q) ||
                r.partNumber.toLowerCase().contains(q) ||
                r.partName.toLowerCase().contains(q) ||
                r.challanNumber.toLowerCase().contains(q);

            return matchesFilter && matchesSearch;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Stats Cards
                    _buildStatsGrid(context, stats),
                    const SizedBox(height: AppSizes.p24),

                    // Controls Header (Search & Filters)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search company, part number, challan...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p16),

                    // Filter Chips
                    Row(
                      children: [
                        _buildFilterChip('All', records.length),
                        const SizedBox(width: 8),
                        _buildFilterChip('Inward', stats.inwardCount),
                        const SizedBox(width: 8),
                        _buildFilterChip('Outward', stats.outwardCount),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p20),

                    // List View / Empty State
                    if (filtered.isEmpty) ...[
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 64, color: theme.disabledColor),
                            const SizedBox(height: 16),
                            Text(
                              'No Inward / Outward records found',
                              style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Log Inward / Outward" to add a new challan record.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 2,
                          crossAxisSpacing: AppSizes.p16,
                          mainAxisSpacing: AppSizes.p16,
                          mainAxisExtent: 210,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final record = filtered[index];
                          return _buildRecordCard(context, record, isOwner);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
      checkmarkColor: theme.colorScheme.primary,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, InwardOutwardStats stats) {
    final columns = ResponsiveLayout.isMobile(context) ? 1 : 3;

    final cards = [
      _StatItem('Total Entries', stats.totalCount.toString(), Icons.swap_horiz_rounded, AppColors.info),
      _StatItem('Inward Entries', stats.inwardCount.toString(), Icons.south_west_rounded, AppColors.success),
      _StatItem('Outward Entries', stats.outwardCount.toString(), Icons.north_east_rounded, AppColors.warning),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: 96,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return CustomCard(
          title: card.title,
          subtitle: card.value,
          icon: card.icon,
          iconColor: card.color,
        );
      },
    );
  }

  Widget _buildRecordCard(BuildContext context, InwardOutwardModel record, bool isOwner) {
    final theme = Theme.of(context);
    final isInward = record.direction.toLowerCase() == 'inward';
    final badgeColor = isInward ? AppColors.success : AppColors.info;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _showRecordDetails(context, record, isOwner),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isInward ? Icons.south_west_rounded : Icons.north_east_rounded,
                          size: 14,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.direction.toUpperCase(),
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(record.date),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p12),

              // Company Name & Challan Number
              Text(
                record.companyName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Challan: ${record.challanNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.p8),

              // Part Details & Quantity
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${record.partNumber} • ${record.partName}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${record.quantity} ${record.quantityUnit}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Divider(height: 16),

              // Footer Photos & Author
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (record.challanPhotoUrls.isNotEmpty) ...[
                        const Icon(Icons.receipt_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${record.challanPhotoUrls.length} Challan', style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 8),
                      ],
                      if (record.materialPhotoUrls.isNotEmpty) ...[
                        const Icon(Icons.photo_library_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${record.materialPhotoUrls.length} Material', style: const TextStyle(fontSize: 11)),
                      ],
                    ],
                  ),
                  Text(
                    'By ${record.createdByName}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(BuildContext context, InwardOutwardModel record, bool isOwner) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${record.direction} Entry Details'),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  tooltip: 'Delete Record',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: dialogCtx,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Entry'),
                        content: const Text('Are you sure you want to delete this record? This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final companyId = ref.read(authProvider).user?.companyId ?? '';
                      await ref.read(inwardOutwardRepositoryProvider).deleteRecord(companyId, record.id);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Record deleted successfully.')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Direction', record.direction),
                  _detailRow('Company / Party', record.companyName),
                  _detailRow('Challan Number', record.challanNumber),
                  _detailRow('Part Number', record.partNumber),
                  _detailRow('Part Name', record.partName),
                  _detailRow('Quantity', '${record.quantity} ${record.quantityUnit}'),
                  _detailRow('Date', DateFormat('dd MMM yyyy').format(record.date)),
                  _detailRow('Logged By', record.createdByName),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Challan Photos View
                  Text('Challan Photos (${record.challanPhotoUrls.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (record.challanPhotoUrls.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: record.challanPhotoUrls.length,
                      itemBuilder: (ctx, idx) {
                        final url = record.challanPhotoUrls[idx];
                        return InkWell(
                          onTap: () => _openImageViewer(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: Colors.grey,
                                child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white)),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    const Text('No challan photos attached', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  
                  const SizedBox(height: 16),

                  // Material Photos View
                  Text('Material Photos (${record.materialPhotoUrls.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (record.materialPhotoUrls.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: record.materialPhotoUrls.length,
                      itemBuilder: (ctx, idx) {
                        final url = record.materialPhotoUrls[idx];
                        return InkWell(
                          onTap: () => _openImageViewer(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    const Text('No material photos attached', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(this.title, this.value, this.icon, this.color);
}
