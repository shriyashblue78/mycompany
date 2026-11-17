import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_field.dart';
import '../widgets/suggested_question_chips.dart';

class CompactAiChatPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String>? onNavigate;
  final void Function(String route, Map<String, dynamic>? extra)? onNavigateWithExtra;

  const CompactAiChatPanel({
    super.key,
    required this.onClose,
    this.onNavigate,
    this.onNavigateWithExtra,
  });

  @override
  ConsumerState<CompactAiChatPanel> createState() => _CompactAiChatPanelState();
}

class _CompactAiChatPanelState extends ConsumerState<CompactAiChatPanel> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleNavigation(String route, [Map<String, dynamic>? extra]) {
    if (widget.onNavigateWithExtra != null) {
      widget.onNavigateWithExtra!(route, extra);
      return;
    }
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
      return;
    }
    // Navigate directly using GoRouter from Riverpod without widget-tree context lookup
    ref.read(routerProvider).go(route, extra: extra);
    widget.onClose();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatState = ref.watch(chatNotifierProvider);
    final chatNotifier = ref.read(chatNotifierProvider.notifier);

    ref.listen<ChatState>(chatNotifierProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 540,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Panel Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF9FAFB),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Primot AI',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ERP Assistant',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_full_rounded, size: 16),
                      onPressed: () {
                        ref.read(routerProvider).push('/ai-chat');
                        widget.onClose();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Message List or Suggested Chips
              Expanded(
                child: chatState.messages.isEmpty
                    ? SuggestedQuestionChips(
                        questions: ChatNotifier.suggestedQuestions.take(3).toList(),
                        onSelected: (q) => chatNotifier.sendMessage(q),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < chatState.messages.length) {
                            return ChatBubble(
                              message: chatState.messages[index],
                              onRetry: () => chatNotifier.retryLastMessage(),
                              onNavigate: (route) => _handleNavigation(route),
                              onNavigateWithExtra: (route, extra) => _handleNavigation(route, extra),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Searching records...',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Input Bar
              ChatInputField(
                isLoading: chatState.isLoading,
                onSend: (text) => chatNotifier.sendMessage(text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

