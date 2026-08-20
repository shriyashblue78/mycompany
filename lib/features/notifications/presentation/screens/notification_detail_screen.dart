import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../../../../core/widgets/polish_widgets.dart';

class NotificationDetailScreen extends ConsumerWidget {
  final String notificationId;

  const NotificationDetailScreen({
    super.key,
    required this.notificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final detailAsync = ref.watch(notificationDetailProvider(notificationId));
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Notification not found'));
          }

          final notif = item.notification;
          final createdByMe = notif.createdByUid == user?.uid;
          final isOwnerOrHR = user?.role == 'Owner' || user?.role == 'HR';
          final canManage = isOwnerOrHR || (user?.role == 'Supervisor' && createdByMe);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Pin status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (notif.isPinned) ...[
                          const SizedBox(width: AppSizes.p12),
                          Tooltip(
                            message: 'Pinned Announcement',
                            child: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withAlpha(26),
                              radius: 20,
                              child: Icon(
                                Icons.push_pin_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.p16),

                    // Metadata row (Chips)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Priority Chip
                        _buildChip(
                          context,
                          label: notif.priority,
                          color: _getPriorityColor(notif.priority),
                        ),
                        // Type Chip
                        _buildChip(
                          context,
                          label: notif.type,
                          color: theme.colorScheme.primary,
                          outlined: true,
                        ),
                        // Read / Unread Status Chip
                        _buildChip(
                          context,
                          label: item.isRead ? 'Read' : 'Unread',
                          color: item.isRead ? Colors.grey : AppColors.warning,
                        ),
                      ],
                    ),
                    const Divider(height: AppSizes.p32),

                    // Author & Time Info Card
                    Card(
                      elevation: 0,
                      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        side: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withAlpha(26),
                              child: Text(
                                notif.createdByName.isNotEmpty ? notif.createdByName[0].toUpperCase() : 'S',
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: AppSizes.p12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif.createdByName,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sent: ${DateFormat('MMMM d, yyyy • h:mm a').format(notif.createdAt)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Audience Info Card (Visible to managers/creators)
                    if (isOwnerOrHR || createdByMe) ...[
                      Text(
                        'Target Audience Details',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.p16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Scope: ${notif.targetType}'),
                            if (notif.targetType == 'Department') ...[
                              const SizedBox(height: 4),
                              Text('Department: ${notif.targetDepartment ?? "N/A"}'),
                            ],
                            if (notif.targetType == 'Employee') ...[
                              const SizedBox(height: 4),
                              Text('Employees: ${notif.targetEmployeeIds.join(", ")}'),
                            ],
                            if (notif.scheduledAt != null) ...[
                              const SizedBox(height: 4),
                              Text('Scheduled For: ${DateFormat('MMMM d, yyyy • h:mm a').format(notif.scheduledAt!)}'),
                            ],
                            if (notif.expiresAt != null) ...[
                              const SizedBox(height: 4),
                              Text('Expires On: ${DateFormat('MMMM d, yyyy • h:mm a').format(notif.expiresAt!)}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.p24),
                    ],

                    // Message Body
                    Text(
                      'Message',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSizes.p20),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        boxShadow: isDark ? [] : [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          )
                        ],
                        border: isDark ? Border.all(color: Colors.white12) : null,
                      ),
                      child: SelectableText(
                        notif.message,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p32),

                    // Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Toggle Read Status Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (user != null) {
                                final repo = ref.read(notificationRepositoryProvider);
                                if (item.isRead) {
                                  repo.markAsUnread(user.companyId, user.employeeId, notif.notificationId);
                                } else {
                                  repo.markAsRead(user.companyId, user.employeeId, notif.notificationId);
                                }
                              }
                            },
                            icon: Icon(item.isRead ? Icons.mark_chat_unread : Icons.mark_chat_read),
                            label: Text(item.isRead ? 'Mark Unread' : 'Mark Read'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                              ),
                            ),
                          ),
                        ),
                        
                        if (canManage) ...[
                          const SizedBox(width: AppSizes.p12),
                          // Edit Button
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            tooltip: 'Edit Announcement',
                            onPressed: () {
                              context.push('/notifications/create', extra: notif);
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withAlpha(26),
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.p12),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                            tooltip: 'Delete Announcement',
                            onPressed: () => _confirmDelete(context, ref, user?.companyId, notif.notificationId),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.error.withAlpha(26),
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required Color color,
    bool outlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withAlpha(38),
        border: outlined ? Border.all(color: color, width: 1.5) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
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

  void _confirmDelete(BuildContext context, WidgetRef ref, String? companyId, String notificationId) async {
    final confirm = await showDeleteConfirmationDialog(
      context: context,
      recordName: 'this announcement',
    );
    if (confirm) {
      try {
        if (companyId != null) {
          await ref.read(notificationRepositoryProvider).deleteNotification(companyId, notificationId);
          if (context.mounted) {
            showFeedbackSnackBar(
              context: context,
              message: 'Announcement deleted successfully.',
            );
            context.pop(); // Go back
          }
        }
      } catch (e) {
        if (context.mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Error deleting announcement: $e',
            isError: true,
          );
        }
      }
    }
  }
}
