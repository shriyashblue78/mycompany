import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/primot_ai_config.dart';

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

  const AiChatResponse({
    required this.reply,
    this.navigationRoute,
    this.navigationTitle,
  });

  const AiChatResponse.text(this.reply)
      : navigationRoute = null,
        navigationTitle = null;

  @override
  String toString() => reply;
}

class PrimotAiApiService {
  final http.Client _client;

  PrimotAiApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Sends a chat message to POST /chat with the caller's fresh Firebase ID token.
  /// Optionally passes recent conversation history for follow-up context retention.
  Future<AiChatResponse> sendMessage({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PrimotAiApiException(
        'You must be signed in to converse with Primot AI.',
        statusCode: 401,
      );
    }

    // Retrieve fresh ID token without forcing refresh unless necessary
    final idToken = await user.getIdToken();
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

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(PrimotAiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? 'I received your request, but no response text was generated.';
        String? navRoute;
        String? navTitle;

        final action = data['action'] as Map<String, dynamic>?;
        if (action != null && action['action'] == 'navigate') {
          final candidateRoute = action['route'] as String?;
          // Strictly reject non-internal or non-slash paths
          if (candidateRoute != null && candidateRoute.startsWith('/')) {
            navRoute = candidateRoute;
            navTitle = action['title'] as String?;
          }
        }

        return AiChatResponse(
          reply: reply,
          navigationRoute: navRoute,
          navigationTitle: navTitle,
        );
      } else if (response.statusCode == 401) {
        throw const PrimotAiApiException(
          'Authentication failed or token has expired. Please log in again.',
          statusCode: 401,
        );
      } else if (response.statusCode == 403) {
        final data = _tryParseJson(response.body);
        final detail = data?['detail'] ?? 'Access denied for your account or company.';
        throw PrimotAiApiException('$detail', statusCode: 403);
      } else if (response.statusCode >= 500) {
        throw PrimotAiApiException(
          'Primot AI service encountered an error (${response.statusCode}). Please ensure the local LLM server is running.',
          statusCode: response.statusCode,
        );
      } else {
        final data = _tryParseJson(response.body);
        final detail = data?['detail'] ?? 'Unexpected server response (${response.statusCode}).';
        throw PrimotAiApiException('$detail', statusCode: response.statusCode);
      }
    } on SocketException catch (_) {
      throw const PrimotAiApiException(
        'Could not connect to Primot AI backend. Please verify the service is running on port 8000.',
      );
    } on TimeoutException catch (_) {
      throw const PrimotAiApiException(
        'Request timed out. The local AI model took longer than expected to process or warm up. Please try again.',
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

