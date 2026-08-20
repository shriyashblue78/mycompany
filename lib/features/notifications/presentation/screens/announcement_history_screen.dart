import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/notification_model.dart';
import '../providers/notifications_provider.dart';

class AnnouncementHistoryScreen extends ConsumerWidget {
  const AnnouncementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    final notificationsAsync = ref.watch(rawNotificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement History'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading history: $err')),
        data: (notifications) {
          // Filter announcements that the manager has permission to see / manage
          // Owner & HR see all
          // Supervisor sees only their department or created by them
          final visibleList = notifications.where((notification) {
            if (user.role == 'Owner' || user.role == 'HR') return true;
            if (user.role == 'Supervisor') {
              return notification.createdByUid == user.uid ||
                  (notification.targetType == 'Department' &&
                      notification.targetDepartment == user.department);
            }
            return false;
          }).toList();

          if (visibleList.isEmpty) {
            return _buildEmptyState(context, theme);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.p24),
            itemCount: visibleList.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSizes.p12),
            itemBuilder: (context, index) {
              final notif = visibleList[index];
              return _buildHistoryCard(context, ref, user.companyId, notif, theme, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    WidgetRef ref,
    String companyId,
    NotificationModel notif,
    ThemeData theme,
    bool isDark,
  ) {
    String targetLabel = 'Company-Wide';
    if (notif.targetType == 'Department') {
      targetLabel = 'Dept: ${notif.targetDepartment}';
    } else if (notif.targetType == 'Employee') {
      targetLabel = '${notif.targetEmployeeIds.length} Employee(s)';
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Priority & Target & Pin button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    const SizedBox(width: AppSizes.p8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.colorScheme.primary.withAlpha(51)),
                      ),
                      child: Text(
                        targetLabel,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    notif.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: notif.isPinned ? theme.colorScheme.primary : Colors.grey,
                  ),
                  tooltip: notif.isPinned ? 'Unpin' : 'Pin',
                  onPressed: () {
                    final updated = notif.copyWith(isPinned: !notif.isPinned);
                    ref.read(notificationRepositoryProvider).updateNotification(companyId, updated);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSizes.p8),

            // Title and Message
            Text(
              notif.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              notif.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withAlpha(200),
              ),
            ),
            const SizedBox(height: AppSizes.p12),

            // Footer info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By ${notif.createdByName} • ${DateFormat('MMM d, yyyy h:mm a').format(notif.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Row(
                  children: [
                    // Edit action
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                      onPressed: () {
                        context.push('/notifications/create', extra: notif);
                      },
                    ),
                    // Delete action
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
                      onPressed: () => _confirmDelete(context, ref, companyId, notif.notificationId),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
              Icons.campaign_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              'No announcements created yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ],
        ),
      ),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, String companyId, String notificationId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Announcement?'),
          content: const Text('This action cannot be undone. All employees will lose access to this announcement.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(notificationRepositoryProvider).deleteNotification(companyId, notificationId);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
