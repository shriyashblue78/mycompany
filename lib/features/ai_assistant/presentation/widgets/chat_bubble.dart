import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onNavigate;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onNavigate,
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
                  if (message.navigationRoute != null) ...[
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
}

