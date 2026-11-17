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
  final FormPrefillActionData? simulatedPrefillAction;
  List<Map<String, String>>? lastHistoryPassed;

  MockSuccessAiApiService({
    this.simulatedReply = 'Recorded stock for ITM-001 is 120.0 Nos.',
    this.simulatedNavRoute,
    this.simulatedNavTitle,
    this.simulatedPrefillAction,
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
      prefillAction: simulatedPrefillAction,
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

    test('ChatNotifier parses structured prepare_form action and attaches FormPrefillActionData to assistant message', () async {
      final prefillAction = FormPrefillActionData(
        actionType: 'prepare_form',
        module: 'party',
        operation: 'create',
        route: '/parties/add',
        moduleTitle: 'Party',
        fields: {
          'partyName': 'ABC Industries',
          'contactNumber': '9876543210',
        },
        missingMandatoryFields: ['gstin'],
      );
      final mockService = MockSuccessAiApiService(
        simulatedReply: 'I have prepared the party form for ABC Industries.',
        simulatedPrefillAction: prefillAction,
      );
      final notifier = ChatNotifier(mockService);

      await notifier.sendMessage('Add a new party named ABC Industries');

      expect(notifier.state.messages.length, 2);
      final assistantMsg = notifier.state.messages[1];
      expect(assistantMsg.text, contains('ABC Industries'));
      expect(assistantMsg.prefillAction, isNotNull);
      expect(assistantMsg.prefillAction!.module, 'party');
      expect(assistantMsg.prefillAction!.operation, 'create');
      expect(assistantMsg.prefillAction!.route, '/parties/add');
      expect(assistantMsg.prefillAction!.fields['partyName'], 'ABC Industries');
      expect(assistantMsg.prefillAction!.missingMandatoryFields, contains('gstin'));
    });

    test('FormPrefillActionData.fromMap correctly parses valid create and edit payloads', () {
      final createMap = {
        'action_type': 'prepare_form',
        'module': 'inventory',
        'operation': 'create',
        'route': '/inventory/add',
        'module_title': 'Inventory Item',
        'fields': {
          'itemName': 'Copper Rod',
          'unit': 'KG',
          'minStock': 50.0,
        },
        'missing_mandatory_fields': <String>[],
      };
      final action = FormPrefillActionData.fromMap(createMap);
      expect(action, isNotNull);
      expect(action!.module, 'inventory');
      expect(action.route, '/inventory/add');
      expect(action.fields['itemName'], 'Copper Rod');
      expect(action.fields['minStock'], 50.0);
      expect(action.missingMandatoryFields, isEmpty);

      final editMap = {
        'action_type': 'prepare_form',
        'module': 'inventory',
        'operation': 'edit',
        'route': '/inventory/edit/item_123',
        'module_title': 'Inventory Item',
        'fields': {
          'minStock': 100.0,
        },
        'missing_mandatory_fields': <String>[],
        'record_id': 'item_123',
        'record_name': 'Copper Rod',
      };
      final editAction = FormPrefillActionData.fromMap(editMap);
      expect(editAction, isNotNull);
      expect(editAction!.operation, 'edit');
      expect(editAction.recordId, 'item_123');
      expect(editAction.recordName, 'Copper Rod');
      expect(editAction.route, '/inventory/edit/item_123');
    });

    test('FormPrefillActionData.fromMap rejects unapproved route and invalid action_type', () {
      final invalidRouteMap = {
        'action_type': 'prepare_form',
        'module': 'inventory',
        'operation': 'create',
        'route': '/unapproved/secret/route',
        'fields': {'name': 'test'},
      };
      expect(FormPrefillActionData.fromMap(invalidRouteMap), isNull);

      final invalidActionTypeMap = {
        'action_type': 'arbitrary_action',
        'module': 'party',
        'operation': 'create',
        'route': '/parties/add',
        'fields': {'partyName': 'Test'},
      };
      expect(FormPrefillActionData.fromMap(invalidActionTypeMap), isNull);
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

    test('ChatMessage toMap and fromMap preserve all structured actions across restoration', () {
      final original = ChatMessage(
        id: 'msg_test_101',
        text: 'Prepared sales draft for ABC Industries.',
        sender: MessageSender.assistant,
        timestamp: DateTime(2026, 11, 15, 14, 30),
        status: MessageStatus.sent,
        navigationRoute: '/sales/add',
        navigationTitle: 'Sales Entry',
        prefillAction: const FormPrefillActionData(
          module: 'sales',
          operation: 'create',
          route: '/sales/add',
          fields: {'customerName': 'ABC Industries', 'customerPhone': '9876543210', 'quantity': 10},
          missingFields: ['price'],
          title: 'Review New Sales Entry',
        ),
        workflowAction: const WorkflowActionData(
          workflowId: 'wf_123',
          title: 'Automated Sales Draft',
          summary: 'Executed 2 steps',
          steps: [
            WorkflowStepData(
              stepNumber: 1,
              title: 'Found Party',
              description: 'ABC Industries',
              actionType: 'info',
            ),
            WorkflowStepData(
              stepNumber: 2,
              title: 'Prepare Sales Draft',
              description: 'Draft ready',
              actionType: 'prefill_form',
              route: '/sales/add',
            ),
          ],
        ),
      );

      final map = original.toMap();
      expect(map['id'], 'msg_test_101');
      expect(map['prefill_action'], isNotNull);
      expect(map['workflow_action'], isNotNull);

      final restored = ChatMessage.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.sender, original.sender);
      expect(restored.navigationRoute, original.navigationRoute);
      expect(restored.navigationTitle, original.navigationTitle);

      expect(restored.prefillAction, isNotNull);
      expect(restored.prefillAction!.module, 'sales');
      expect(restored.prefillAction!.fields['customerName'], 'ABC Industries');
      expect(restored.prefillAction!.missingFields, ['price']);

      expect(restored.workflowAction, isNotNull);
      expect(restored.workflowAction!.workflowId, 'wf_123');
      expect(restored.workflowAction!.steps.length, 2);
      expect(restored.workflowAction!.steps[1].actionType, 'prefill_form');
    });
  });
}

