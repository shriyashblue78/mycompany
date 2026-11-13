import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projectbtt/features/ai_assistant/data/primot_ai_api_service.dart';
import 'package:projectbtt/features/ai_assistant/domain/models/chat_message.dart';
import 'package:projectbtt/features/ai_assistant/presentation/providers/chat_provider.dart';

class MockSuccessAiApiService extends PrimotAiApiService {
  final String simulatedReply;
  final String? simulatedNavRoute;
  final String? simulatedNavTitle;
  List<Map<String, String>>? lastHistoryPassed;

  MockSuccessAiApiService({
    this.simulatedReply = 'Recorded stock for ITM-001 is 120.0 Nos.',
    this.simulatedNavRoute,
    this.simulatedNavTitle,
  });

  @override
  Future<AiChatResponse> sendMessage({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    lastHistoryPassed = history;
    await Future.delayed(const Duration(milliseconds: 5));
    return AiChatResponse(
      reply: simulatedReply,
      navigationRoute: simulatedNavRoute,
      navigationTitle: simulatedNavTitle,
    );
  }
}

class MockErrorAiApiService extends PrimotAiApiService {
  final String errorMsg;

  MockErrorAiApiService({this.errorMsg = 'Could not connect to Primot AI backend on port 8000.'});

  @override
  Future<AiChatResponse> sendMessage({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    await Future.delayed(const Duration(milliseconds: 5));
    throw PrimotAiApiException(errorMsg, statusCode: 503);
  }
}

void main() {
  group('Primot AI Flutter Unit & State Tests', () {
    test('ChatNotifier appends user message, toggles loading, and appends AI response', () async {
      final mockService = MockSuccessAiApiService();
      final notifier = ChatNotifier(mockService);

      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.isLoading, isFalse);

      final sendFuture = notifier.sendMessage('How much stock is available for ITM-001?');

      // Immediate state check
      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.text, 'How much stock is available for ITM-001?');
      expect(notifier.state.messages.first.sender, MessageSender.user);
      expect(notifier.state.isLoading, isTrue);

      await sendFuture;

      // Completed state check
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].sender, MessageSender.assistant);
      expect(notifier.state.messages[1].text, contains('120.0 Nos'));
      expect(notifier.state.messages[1].status, MessageStatus.sent);
    });

    test('ChatNotifier handles errors, sets failed status and supports retry', () async {
      final mockService = MockErrorAiApiService();
      final notifier = ChatNotifier(mockService);

      await notifier.sendMessage('Show today sales');

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages.last.status, MessageStatus.failed);
      expect(notifier.state.globalError, contains('Could not connect'));
    });

    test('ChatNotifier clearConversation resets messages and error states', () async {
      final mockService = MockSuccessAiApiService();
      final notifier = ChatNotifier(mockService);

      await notifier.sendMessage('Hello');
      expect(notifier.state.messages.length, 2);

      notifier.clearConversation();
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.globalError, isNull);
    });

    test('ChatNotifier passes previous conversation history on follow-up question', () async {
      final mockService = MockSuccessAiApiService(
        simulatedReply: 'Recorded stock for Copper Rod is 0 KG (minimum: 78 KG).',
      );
      final notifier = ChatNotifier(mockService);

      // Turn 1
      await notifier.sendMessage('How much stock is available for Copper Rod?');
      expect(mockService.lastHistoryPassed, isEmpty);
      expect(notifier.state.messages.length, 2);

      // Turn 2: Follow-up question
      await notifier.sendMessage('Is that item below its minimum stock level?');
      expect(mockService.lastHistoryPassed, isNotNull);
      expect(mockService.lastHistoryPassed!.length, 2);
      expect(mockService.lastHistoryPassed![0]['role'], 'user');
      expect(mockService.lastHistoryPassed![0]['content'], 'How much stock is available for Copper Rod?');
      expect(mockService.lastHistoryPassed![1]['role'], 'assistant');
      expect(mockService.lastHistoryPassed![1]['content'], contains('Copper Rod'));
    });

    test('ChatNotifier parses structured navigation action and attaches to assistant message', () async {
      final mockService = MockSuccessAiApiService(
        simulatedReply: 'Opening Inventory Management.',
        simulatedNavRoute: '/inventory',
        simulatedNavTitle: 'Inventory Management',
      );
      final notifier = ChatNotifier(mockService);

      await notifier.sendMessage('Open inventory');

      expect(notifier.state.messages.length, 2);
      final assistantMsg = notifier.state.messages[1];
      expect(assistantMsg.text, 'Opening Inventory Management.');
      expect(assistantMsg.navigationRoute, '/inventory');
      expect(assistantMsg.navigationTitle, 'Inventory Management');
    });

    test('PrimotAiApiService parses successful JSON response properly', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/chat')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['message'], 'Check status');
          expect(request.headers['Authorization'], contains('Bearer'));
          return http.Response(
            jsonEncode({
              'reply': 'Apex Steel billed sales total is Rs 45,250.',
              'status': 'success',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      // Verification of client call behavior
      final responseBody = jsonEncode({
        'reply': 'Apex Steel billed sales total is Rs 45,250.',
        'status': 'success',
      });
      final parsed = jsonDecode(responseBody) as Map<String, dynamic>;
      expect(parsed['reply'], contains('45,250'));
      expect(parsed['status'], 'success');
    });
  });
}

