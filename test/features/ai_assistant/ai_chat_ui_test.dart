import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:projectbtt/core/routing/app_router.dart';
import 'package:projectbtt/features/ai_assistant/domain/models/chat_message.dart';
import 'package:projectbtt/features/ai_assistant/data/primot_ai_api_service.dart';
import 'package:projectbtt/features/ai_assistant/presentation/providers/chat_provider.dart';
import 'package:projectbtt/features/ai_assistant/presentation/screens/ai_chat_screen.dart';
import 'package:projectbtt/features/ai_assistant/presentation/widgets/chat_bubble.dart';
import 'package:projectbtt/features/ai_assistant/presentation/widgets/chat_input_field.dart';
import 'package:projectbtt/features/ai_assistant/presentation/widgets/suggested_question_chips.dart';
import 'package:projectbtt/features/ai_assistant/presentation/widgets/compact_ai_chat_panel.dart';

class MockDelayedSuccessApiService extends PrimotAiApiService {
  final String simulatedReply;
  final String? simulatedNavRoute;
  final String? simulatedNavTitle;
  final FormPrefillActionData? simulatedPrefillAction;

  MockDelayedSuccessApiService({
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
    await Future.delayed(const Duration(milliseconds: 30));
    return AiChatResponse(
      reply: simulatedReply,
      navigationRoute: simulatedNavRoute,
      navigationTitle: simulatedNavTitle,
      prefillAction: simulatedPrefillAction,
    );
  }
}

class MockDelayedErrorApiService extends PrimotAiApiService {
  @override
  Future<AiChatResponse> sendMessage({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    await Future.delayed(const Duration(milliseconds: 30));
    throw const PrimotAiApiException(
      'Primot AI service notice: Local LLM server is unavailable at http://127.0.0.1:8080.',
      statusCode: 503,
    );
  }
}

void main() {
  group('Primot AI Widget and UI End-to-End Tests', () {
    testWidgets('Empty chat screen displays suggested questions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(MockDelayedSuccessApiService()),
          ],
          child: const MaterialApp(
            home: AiChatScreen(),
          ),
        ),
      );

      expect(find.text('How can Primot AI help you today?'), findsOneWidget);
      expect(find.byType(SuggestedQuestionChips), findsOneWidget);
      expect(find.byType(ChatInputField), findsOneWidget);
      expect(find.text('Ask in English, Hindi, or Hinglish...'), findsOneWidget);
    });

    testWidgets('Tapping suggested question sends message and renders AI response', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(MockDelayedSuccessApiService()),
          ],
          child: const MaterialApp(
            home: AiChatScreen(),
          ),
        ),
      );

      final chipFinder = find.text('How much stock is available for ITM-001?');
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pump(); // Start request

      // Verify user message bubble appeared and loading indicator is present
      expect(find.text('How much stock is available for ITM-001?'), findsOneWidget);
      expect(find.text('Primot AI is checking records...'), findsOneWidget);

      // Settle response
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Recorded stock for ITM-001 is 120.0 Nos.'), findsOneWidget);
      expect(find.byType(ChatBubble), findsNWidgets(2));
    });

    testWidgets('Error state displays retry button and handles retry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(MockDelayedErrorApiService()),
          ],
          child: const MaterialApp(
            home: AiChatScreen(),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Apex Steel ke sales kitne hue?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.textContaining('Local LLM server is unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('CompactAiChatPanel renders without Overlay crash and can be closed', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(MockDelayedSuccessApiService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CompactAiChatPanel(
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Primot AI'), findsOneWidget);
      expect(find.text('ERP Assistant'), findsOneWidget);

      final closeBtn = find.byIcon(Icons.close_rounded);
      expect(closeBtn, findsOneWidget);

      await tester.tap(closeBtn);
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('Pressing Enter key on ChatInputField sends message', (tester) async {
      String? sentText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputField(
              onSend: (text) => sentText = text,
              isLoading: false,
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Stock of copper rod');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(sentText, 'Stock of copper rod');
    });

    testWidgets('ChatBubble renders clickable Go to [Title] button and executes onNavigate', (tester) async {
      String? navigatedRoute;

      final msg = ChatMessage(
        id: 'msg_1',
        text: 'Opening Inventory Management.',
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        navigationRoute: '/inventory',
        navigationTitle: 'Inventory Management',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: msg,
              onNavigate: (route) => navigatedRoute = route,
            ),
          ),
        ),
      );

      // Verify the navigation button is rendered with the title
      expect(find.text('Go to Inventory Management'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);

      // Tap navigation button
      await tester.tap(find.text('Go to Inventory Management'));
      await tester.pump();

      expect(navigatedRoute, '/inventory');
    });

    testWidgets('CompactAiChatPanel navigates via GoRouter and closes panel safely', (tester) async {
      bool closed = false;
      String currentRoute = '/';

      final mockApi = MockDelayedSuccessApiService(
        simulatedReply: 'Opening Inventory Management.',
        simulatedNavRoute: '/inventory',
        simulatedNavTitle: 'Inventory Management',
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              currentRoute = '/';
              return Scaffold(
                body: CompactAiChatPanel(
                  onClose: () => closed = true,
                ),
              );
            },
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) {
              currentRoute = '/inventory';
              return const Scaffold(body: Text('Inventory Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(mockApi),
            routerProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Open Inventory');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Go to Inventory Management'), findsOneWidget);

      await tester.tap(find.text('Go to Inventory Management'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(currentRoute, '/inventory');
      expect(find.text('Inventory Screen'), findsOneWidget);
    });

    testWidgets('ChatBubble renders FormPrefill review card with field chips and button', (tester) async {
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

      final message = ChatMessage(
        id: 'msg_prefill_1',
        text: 'I have prepared the party form for ABC Industries.',
        sender: MessageSender.assistant,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        prefillAction: prefillAction,
      );

      String? navigatedRoute;
      Map<String, dynamic>? navigatedExtra;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: message,
              onNavigateWithExtra: (route, extra) {
                navigatedRoute = route;
                navigatedExtra = extra;
              },
            ),
          ),
        ),
      );

      expect(find.text('Review New Party'), findsOneWidget);
      expect(find.text('partyName: ABC Industries'), findsOneWidget);
      expect(find.text('contactNumber: 9876543210'), findsOneWidget);
      expect(find.text('Missing Required Fields:'), findsOneWidget);
      expect(find.text('gstin'), findsOneWidget);
      expect(find.text('Complete Missing Fields in Form'), findsOneWidget);

      await tester.tap(find.text('Complete Missing Fields in Form'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/parties/add');
      expect(navigatedExtra?['partyName'], 'ABC Industries');
      expect(navigatedExtra?['contactNumber'], '9876543210');
    });

    testWidgets('CompactAiChatPanel form prefill review opens target form with extra fields', (tester) async {
      String currentRoute = '/owner-dashboard';
      Map<String, dynamic>? receivedExtra;
      bool closed = false;

      final prefillAction = FormPrefillActionData(
        actionType: 'prepare_form',
        module: 'inventory',
        operation: 'create',
        route: '/inventory/add',
        moduleTitle: 'Inventory Item',
        fields: {
          'itemName': 'Copper Rod',
          'unit': 'KG',
          'minStock': 50.0,
        },
        missingMandatoryFields: <String>[],
      );

      final mockApi = MockDelayedSuccessApiService(
        simulatedReply: 'I have prepared the item form for Copper Rod.',
        simulatedPrefillAction: prefillAction,
      );

      final router = GoRouter(
        initialLocation: '/owner-dashboard',
        routes: [
          GoRoute(
            path: '/owner-dashboard',
            builder: (context, state) {
              currentRoute = '/owner-dashboard';
              return Scaffold(
                body: CompactAiChatPanel(
                  onClose: () => closed = true,
                ),
              );
            },
          ),
          GoRoute(
            path: '/inventory/add',
            builder: (context, state) {
              currentRoute = '/inventory/add';
              receivedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Add Inventory Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(mockApi),
            routerProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Create an item called Copper Rod with unit KG and minimum stock 50');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Review New Inventory Item'), findsOneWidget);
      expect(find.text('itemName: Copper Rod'), findsOneWidget);
      expect(find.text('Review & Save in Form'), findsOneWidget);

      await tester.tap(find.text('Review & Save in Form'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(currentRoute, '/inventory/add');
      expect(receivedExtra?['itemName'], 'Copper Rod');
      expect(receivedExtra?['unit'], 'KG');
      expect(receivedExtra?['minStock'], 50.0);
      expect(find.text('Add Inventory Screen'), findsOneWidget);
    });

    testWidgets('AiChatScreen full-screen chat navigates via GoRouter', (tester) async {
      String currentRoute = '/ai-chat';

      final mockApi = MockDelayedSuccessApiService(
        simulatedReply: 'Opening Inventory Management.',
        simulatedNavRoute: '/inventory',
        simulatedNavTitle: 'Inventory Management',
      );

      final router = GoRouter(
        initialLocation: '/ai-chat',
        routes: [
          GoRoute(
            path: '/ai-chat',
            builder: (context, state) {
              currentRoute = '/ai-chat';
              return const AiChatScreen();
            },
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) {
              currentRoute = '/inventory';
              return const Scaffold(body: Text('Inventory Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primotAiApiServiceProvider.overrideWithValue(mockApi),
            routerProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Open Inventory');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Go to Inventory Management'), findsOneWidget);

      await tester.tap(find.text('Go to Inventory Management'));
      await tester.pumpAndSettle();

      expect(currentRoute, '/inventory');
      expect(find.text('Inventory Screen'), findsOneWidget);
    });
  });
}

