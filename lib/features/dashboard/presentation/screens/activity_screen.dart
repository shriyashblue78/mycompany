import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../providers/dashboard_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Selected filter state
final activityFilterProvider = StateProvider<String>((ref) => 'All');

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activitiesAsync = ref.watch(companyActivitiesProvider);
    final selectedFilter = ref.watch(activityFilterProvider);

    final authState = ref.watch(authProvider);
    final company = authState.selectedCompany ?? 'Apex Industries';

    // List of filters
    final filters = [
      'All',
      'Attendance',
      'Production',
      'Purchase',
      'Sales',
      'Leave',
      'Tasks',
      'Inventory',
    ];

    final isMobile = ResponsiveLayout.isMobile(context);

    Widget buildBody(List<ActivityItem> allActivities) {
      final filteredActivities = allActivities.where((act) {
        if (selectedFilter == 'All') return true;
        return act.moduleType.toLowerCase() == selectedFilter.toLowerCase();
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header description
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p16 : AppSizes.p24,
              vertical: AppSizes.p16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company Activity Feed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A chronological log of all recent system and module activities.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Filter Chips
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: AppSizes.p12),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? AppSizes.p16 : AppSizes.p24,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;
                return ChoiceChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: isDark ? theme.colorScheme.primary : AppColors.primaryLight,
                  backgroundColor: isDark ? theme.colorScheme.surface : Colors.grey.shade200,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(activityFilterProvider.notifier).state = filter;
                    }
                  },
                );
              },
            ),
          ),

          // Timeline Feed List
          Expanded(
            child: filteredActivities.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 64,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No activities found for category "$selectedFilter".',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? AppSizes.p16 : AppSizes.p24,
                      vertical: AppSizes.p8,
                    ),
                    itemCount: filteredActivities.length,
                    itemBuilder: (context, index) {
                      final act = filteredActivities[index];
                      final dateStr =
                          '${act.dateTime.day}/${act.dateTime.month}/${act.dateTime.year}';
                      final timeStr =
                          '${act.dateTime.hour.toString().padLeft(2, '0')}:${act.dateTime.minute.toString().padLeft(2, '0')}';

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: act.color.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    act.icon,
                                    color: act.color,
                                    size: 16,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: index == filteredActivities.length - 1 ? 0 : 2,
                                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          act.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$dateStr $timeStr',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (act.description.isNotEmpty) ...[
                                    Text(
                                      act.description,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: act.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      act.moduleType.toUpperCase(),
                                      style: TextStyle(
                                        color: act.color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text('$company - Activities'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: activitiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Text(
                'Error loading activities: $err',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
          data: (allActivities) => isMobile
              ? buildBody(allActivities)
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                    child: buildBody(allActivities),
                  ),
                ),
        ),
      ),
    );
  }
}
