import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final notificationsAsync = ref.watch(filteredNotificationsProvider);
    final searchQuery = ref.watch(notificationSearchQueryProvider);
    final selectedType = ref.watch(notificationTypeFilterProvider);
    final selectedPriority = ref.watch(notificationPriorityFilterProvider);
    final selectedReadStatus = ref.watch(notificationReadStatusFilterProvider);
    final selectedDate = ref.watch(notificationDateFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Notifications'),
        actions: [
          notificationsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final unreadList = list.where((item) => !item.isRead).toList();
              if (unreadList.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                icon: Icon(Icons.done_all, color: theme.colorScheme.primary),
                label: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  final authState = ref.read(authProvider);
                  if (authState.user != null) {
                    final unreadIds = unreadList.map((item) => item.notification.notificationId).toList();
                    await ref.read(notificationRepositoryProvider).markAllAsRead(
                      authState.user!.companyId,
                      authState.user!.employeeId,
                      unreadIds,
                    );
                  }
                },
              );
            },
          ),
        ],
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: Column(
        children: [
          // Filter section
          _buildFilterHeader(context, ref, searchQuery, selectedType, selectedPriority, selectedReadStatus, selectedDate, theme, isDark),
          
          // Main list or states
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState(context, theme);
                }
                return _buildListView(context, ref, list, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(
    BuildContext context,
    WidgetRef ref,
    String query,
    String? type,
    String? priority,
    String? readStatus,
    DateTime? date,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withAlpha(26),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Input
          TextField(
            onChanged: (val) => ref.read(notificationSearchQueryProvider.notifier).state = val,
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: query,
                selection: TextSelection.collapsed(offset: query.length),
              ),
            ),
            decoration: InputDecoration(
              hintText: 'Search by title or content...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => ref.read(notificationSearchQueryProvider.notifier).state = '',
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSizes.p16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p12),

          // Dropdowns Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type Filter
                _buildDropdownFilter(
                  hint: 'Type',
                  value: type,
                  items: ['All', ...kNotificationTypes],
                  onChanged: (val) {
                    ref.read(notificationTypeFilterProvider.notifier).state = val == 'All' ? null : val;
                  },
                ),
                const SizedBox(width: AppSizes.p8),

                // Priority Filter
                _buildDropdownFilter(
                  hint: 'Priority',
                  value: priority,
                  items: ['All', ...kNotificationPriorities],
                  onChanged: (val) {
                    ref.read(notificationPriorityFilterProvider.notifier).state = val == 'All' ? null : val;
                  },
                ),
                const SizedBox(width: AppSizes.p8),

                // Read/Unread Filter
                _buildDropdownFilter(
                  hint: 'Status',
                  value: readStatus,
                  items: ['All', 'Read', 'Unread'],
                  onChanged: (val) {
                    ref.read(notificationReadStatusFilterProvider.notifier).state = val == 'All' ? null : val;
                  },
                ),
                const SizedBox(width: AppSizes.p8),

                // Date Filter
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      ref.read(notificationDateFilterProvider.notifier).state = picked;
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    date != null ? DateFormat('MMM d, yyyy').format(date) : 'Filter Date',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: AppSizes.p4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      ref.read(notificationDateFilterProvider.notifier).state = null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? 'All',
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No notifications found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              'Try adjusting your search query or dropdown filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    List<NotificationWithReadState> list,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.p16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final item = list[index];
        final notif = item.notification;

        return Card(
          margin: EdgeInsets.zero,
          elevation: item.isRead ? 0 : 2,
          color: item.isRead
              ? (isDark ? theme.colorScheme.surface : Colors.grey.shade50)
              : (isDark ? theme.colorScheme.surface.withAlpha(200) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(
              color: item.isRead
                  ? Colors.transparent
                  : theme.colorScheme.primary.withAlpha(51),
              width: 1.5,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: item.isRead
                  ? null
                  : Border(
                      left: BorderSide(
                        color: _getPriorityColor(notif.priority),
                        width: 4.0,
                      ),
                    ),
            ),
            child: ListTile(
              onTap: () {
                if (!item.isRead) {
                  final authState = ref.read(authProvider);
                  if (authState.user != null) {
                    ref.read(notificationRepositoryProvider).markAsRead(
                          authState.user!.companyId,
                          authState.user!.employeeId,
                          notif.notificationId,
                        );
                  }
                }
                context.push('/notifications/${notif.notificationId}');
              },
              leading: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: _getPriorityColor(notif.priority).withAlpha(38),
                    child: Icon(
                      _getIconForType(notif.type),
                      color: _getPriorityColor(notif.priority),
                    ),
                  ),
                  if (!item.isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      notif.title,
                      style: TextStyle(
                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (notif.isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${notif.type} • ${notif.createdByName}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, h:mm a').format(notif.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(notif.priority).withAlpha(38),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notif.priority,
                      style: TextStyle(
                        color: _getPriorityColor(notif.priority),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!item.isRead) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 20),
                      onPressed: () {
                        final authState = ref.read(authProvider);
                        if (authState.user != null) {
                          ref.read(notificationRepositoryProvider).markAsRead(
                                authState.user!.companyId,
                                authState.user!.employeeId,
                                notif.notificationId,
                              );
                        }
                      },
                      tooltip: 'Mark as read',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return AppColors.error;
      case 'High':
        return AppColors.warning;
      case 'Medium':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Announcement':
        return Icons.campaign_rounded;
      case 'Task Update':
        return Icons.assignment_rounded;
      case 'Leave Update':
        return Icons.time_to_leave_rounded;
      case 'Attendance Reminder':
        return Icons.fingerprint_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
