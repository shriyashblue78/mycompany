import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../data/primot_ai_api_service.dart';

final primotAiApiServiceProvider = Provider<PrimotAiApiService>((ref) {
  final service = PrimotAiApiService();
  ref.onDispose(service.dispose);
  return service;
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? globalError;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.globalError,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? globalError,
    bool clearGlobalError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      globalError: clearGlobalError ? null : (globalError ?? this.globalError),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final PrimotAiApiService _apiService;

  ChatNotifier(this._apiService) : super(const ChatState());

  /// Suggested question chips for the user
  static const List<String> suggestedQuestions = [
    'How much stock is available for ITM-001?',
    "Show today's sales summary.",
    "Summarize this month's purchases.",
    'Find the party named Apex Steel.',
    "What is the total billed sales for a party?",
  ];

  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.isLoading) return;

    final userMsgId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final userMsg = ChatMessage(
      id: userMsgId,
      text: cleanText,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    // Extract prior conversation history for follow-up context retention.
    // Limit to the most recent 6 messages to optimize context window and payload size.
    final history = state.messages
        .where((m) =>
            m.status == MessageStatus.sent &&
            (m.sender == MessageSender.user || m.sender == MessageSender.assistant))
        .map((m) => {
              'role': m.sender == MessageSender.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
    final recentHistory = history.length > 6 ? history.sublist(history.length - 6) : history;

    // Append user message & activate loading state
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearGlobalError: true,
    );

    try {
      final response = await _apiService.sendMessage(
        message: cleanText,
        history: recentHistory,
      );
      final aiMsg = ChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        text: response.reply,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        navigationRoute: response.navigationRoute,
        navigationTitle: response.navigationTitle,
        prefillAction: response.prefillAction,
        reportAction: response.reportAction,
        workflowAction: response.workflowAction,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      final failedAiMsg = ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        text: errorMsg,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.failed,
        errorMessage: errorMsg,
      );

      state = state.copyWith(
        messages: [...state.messages, failedAiMsg],
        isLoading: false,
        globalError: errorMsg,
      );
    }
  }

  /// Retries sending a previous failed user query
  Future<void> retryLastMessage() async {
    for (int i = state.messages.length - 1; i >= 0; i--) {
      final msg = state.messages[i];
      if (msg.sender == MessageSender.user && msg.text.isNotEmpty) {
        await sendMessage(msg.text);
        break;
      }
    }
  }

  void clearConversation() {
    state = const ChatState();
  }
}

final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final api = ref.watch(primotAiApiServiceProvider);
  return ChatNotifier(api);
});
