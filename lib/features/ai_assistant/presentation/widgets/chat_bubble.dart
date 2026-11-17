import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/chat_message.dart';
import 'visual_report_card.dart';
import 'workflow_automation_card.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onNavigate;
  final void Function(String route, Map<String, dynamic>? extra)? onNavigateWithExtra;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onNavigate,
    this.onNavigateWithExtra,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.sender == MessageSender.user;
    final isFailed = message.status == MessageStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primaryLight.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    : isFailed
                        ? (isDark ? const Color(0xFF451A1A) : const Color(0xFFFFEBEE))
                        : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? Colors.transparent
                      : isFailed
                          ? (isDark ? AppColors.error.withOpacity(0.4) : AppColors.error.withOpacity(0.3))
                          : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isUser
                          ? Colors.white
                          : isFailed
                              ? (isDark ? const Color(0xFFFCA5A5) : AppColors.error)
                              : (isDark ? Colors.white : const Color(0xFF1F2937)),
                      fontWeight: isFailed ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (message.workflowAction != null) ...[
                    const SizedBox(height: 10),
                    WorkflowAutomationCard(
                      workflow: message.workflowAction!,
                      isDark: isDark,
                      onNavigate: onNavigate,
                      onNavigateWithExtra: onNavigateWithExtra,
                    ),
                  ],
                  if (message.reportAction != null) ...[
                    const SizedBox(height: 10),
                    VisualReportCard(report: message.reportAction!, isDark: isDark),
                  ],
                  if (message.prefillAction != null) ...[
                    const SizedBox(height: 10),
                    _buildPrefillReviewCard(context, message.prefillAction!, isDark),
                  ],
                  if (message.navigationRoute != null && message.prefillAction == null) ...[
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final route = message.navigationRoute!;
                          if (route.startsWith('/')) {
                            if (onNavigate != null) {
                              onNavigate!(route);
                            } else {
                              if (context.mounted) {
                                context.push(route);
                              }
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryContainerDark.withOpacity(0.5)
                                : AppColors.primaryContainerLight.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.primaryDark.withOpacity(0.5)
                                  : AppColors.primaryLight.withOpacity(0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 15,
                                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Go to ${message.navigationTitle ?? "Module"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isFailed && onRetry != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrefillReviewCard(
    BuildContext context,
    FormPrefillActionData action,
    bool isDark,
  ) {
    final isEdit = action.operation == 'edit';
    final accentColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final containerColor = isDark
        ? AppColors.primaryContainerDark.withOpacity(0.3)
        : AppColors.primaryContainerLight.withOpacity(0.4);
    final borderColor = isDark
        ? AppColors.primaryDark.withOpacity(0.4)
        : AppColors.primaryLight.withOpacity(0.3);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEdit ? Icons.edit_note_rounded : Icons.post_add_rounded,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEdit
                      ? 'Review Update: ${action.recordName ?? action.moduleTitle}'
                      : 'Review New ${action.moduleTitle}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          if (action.fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: action.fields.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFD1D5DB),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (action.missingMandatoryFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF87171), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                      SizedBox(width: 5),
                      Text(
                        'Missing Required Fields:',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: action.missingMandatoryFields.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
                        ),
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Form cannot be saved until these fields are completed.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF7F1D1D), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (action.route.startsWith('/')) {
                  if (onNavigateWithExtra != null) {
                    onNavigateWithExtra!(action.route, action.fields);
                  } else if (onNavigate != null) {
                    onNavigate!(action.route);
                  } else {
                    if (context.mounted) {
                      context.push(action.route, extra: action.fields);
                    }
                  }
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: Text(
                action.missingMandatoryFields.isNotEmpty
                    ? 'Complete Missing Fields in Form'
                    : 'Review & ${isEdit ? "Update" : "Save"} in Form',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

