import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/primot_ai_config.dart';
import '../domain/models/chat_message.dart';

class PrimotAiApiException implements Exception {
  final String message;
  final int? statusCode;

  const PrimotAiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AiChatResponse {
  final String reply;
  final String? navigationRoute;
  final String? navigationTitle;
  final FormPrefillActionData? prefillAction;
  final BusinessReportActionData? reportAction;
  final WorkflowActionData? workflowAction;

  const AiChatResponse({
    required this.reply,
    this.navigationRoute,
    this.navigationTitle,
    this.prefillAction,
    this.reportAction,
    this.workflowAction,
  });

  const AiChatResponse.text(this.reply)
      : navigationRoute = null,
        navigationTitle = null,
        prefillAction = null,
        reportAction = null,
        workflowAction = null;

  @override
  String toString() => reply;
}

class PrimotAiApiService {
  final http.Client _client;
  final FirebaseAuth? _auth;

  PrimotAiApiService({
    http.Client? client,
    FirebaseAuth? auth,
  })  : _client = client ?? http.Client(),
        _auth = auth;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  /// Sends a chat message to POST /chat with the caller's fresh Firebase ID token.
  /// Optionally passes recent conversation history for follow-up context retention.
  Future<AiChatResponse> sendMessage({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const PrimotAiApiException(
        'You must be signed in to converse with Primot AI.',
        statusCode: 401,
      );
    }

    // Retrieve fresh ID token without forcing refresh unless necessary
    String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const PrimotAiApiException(
        'Unable to retrieve authentication credentials. Please sign in again.',
        statusCode: 401,
      );
    }

    final uri = Uri.parse('${PrimotAiConfig.baseUrl}/chat');

    try {
      final payload = <String, dynamic>{
        'message': message,
      };
      if (history != null && history.isNotEmpty) {
        payload['history'] = history;
      }

      final bodyJson = jsonEncode(payload);

      http.Response response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: bodyJson,
          )
          .timeout(PrimotAiConfig.requestTimeout);

      // If token expired, force a fresh ID token and retry once
      if (response.statusCode == 401) {
        final freshToken = await user.getIdToken(true);
        if (freshToken != null && freshToken.isNotEmpty && freshToken != idToken) {
          idToken = freshToken;
          response = await _client
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: bodyJson,
              )
              .timeout(PrimotAiConfig.requestTimeout);
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? 'I received your request, but no response text was generated.';
        String? navRoute;
        String? navTitle;

        final action = data['action'] as Map<String, dynamic>?;
        FormPrefillActionData? prefillAct;
        BusinessReportActionData? reportAct;
        WorkflowActionData? workflowAct;

        if (action != null) {
          final actionType = action['action'] as String?;
          final candidateRoute = action['route'] as String?;

          if (actionType == 'workflow_automation') {
            workflowAct = WorkflowActionData.fromMap(action);
            final rawSteps = action['steps'] as List<dynamic>? ?? [];
            for (final s in rawSteps) {
              if (s is Map<String, dynamic>) {
                final sType = s['action_type'] as String?;
                final sPayload = s['payload'] is Map<String, dynamic>
                    ? s['payload'] as Map<String, dynamic>
                    : <String, dynamic>{};
                if (sType == 'prefill_form' && prefillAct == null) {
                  prefillAct = FormPrefillActionData.fromMap(sPayload);
                } else if (sType == 'navigate' && navRoute == null) {
                  navRoute = (s['route'] as String?) ?? (sPayload['route'] as String?);
                  navTitle = (s['title'] as String?) ?? (sPayload['title'] as String?);
                }
              }
            }
          } else if (actionType == 'business_report') {
            reportAct = BusinessReportActionData.fromMap(action);
          } else if (candidateRoute != null && candidateRoute.startsWith('/')) {
            if (actionType == 'navigate') {
              navRoute = candidateRoute;
              navTitle = action['title'] as String?;
            } else if (actionType == 'prefill_form') {
              final mod = (action['module'] as String?)?.toLowerCase();
              final op = (action['operation'] as String?)?.toLowerCase();
              const allowedMods = {'parties', 'items', 'employees', 'sales', 'purchases'};

              if (mod != null && allowedMods.contains(mod) && (op == 'create' || op == 'edit')) {
                final fields = action['fields'] as Map<String, dynamic>? ?? {};
                final missingRaw = action['missing_fields'] as List<dynamic>? ?? [];
                final missing = missingRaw.map((e) => e.toString()).toList();

                prefillAct = FormPrefillActionData(
                  module: mod,
                  operation: op!,
                  route: candidateRoute,
                  recordId: action['record_id'] as String?,
                  recordTitle: action['record_title'] as String?,
                  fields: fields,
                  missingFields: missing,
                  title: (action['title'] as String?) ?? 'Review & Save Form',
                );
              }
            }
          }
        }

        return AiChatResponse(
          reply: reply,
          navigationRoute: navRoute,
          navigationTitle: navTitle,
          prefillAction: prefillAct,
          reportAction: reportAct,
          workflowAction: workflowAct,
        );
      } else if (response.statusCode == 401) {
        throw const PrimotAiApiException(
          'Authentication failed or session has expired. Please log in again.',
          statusCode: 401,
        );
      } else if (response.statusCode == 403) {
        final data = _tryParseJson(response.body);
        final detail = data?['detail'] ?? 'Access denied for your account or company.';
        throw PrimotAiApiException('$detail', statusCode: 403);
      } else if (response.statusCode >= 500) {
        final data = _tryParseJson(response.body);
        final detail = data?['detail'] ??
            'Primot AI service encountered an error (${response.statusCode}). Please try again later.';
        throw PrimotAiApiException('$detail', statusCode: response.statusCode);
      } else {
        final data = _tryParseJson(response.body);
        final detail = data?['detail'] ?? 'Unexpected server response (${response.statusCode}).';
        throw PrimotAiApiException('$detail', statusCode: response.statusCode);
      }
    } on SocketException catch (_) {
      throw const PrimotAiApiException(
        'Could not connect to Primot AI backend at https://api.primotai.tech. Please check your internet connection and try again.',
      );
    } on TimeoutException catch (_) {
      throw const PrimotAiApiException(
        'Request timed out. The Primot AI service took longer than expected to respond. Please try again.',
      );
    } on http.ClientException catch (e) {
      throw PrimotAiApiException('Network error connecting to Primot AI: ${e.message}');
    } on FormatException catch (_) {
      throw const PrimotAiApiException('Invalid response format received from AI backend.');
    } catch (e) {
      if (e is PrimotAiApiException) rethrow;
      throw PrimotAiApiException('Failed to get answer: $e');
    }
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

