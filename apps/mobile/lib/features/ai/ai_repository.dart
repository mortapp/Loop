import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_providers.dart';

/// One turn's result from `/api/ai/chat` or `/api/ai/confirm` — mirrors
/// apps/web/src/app/api/ai/chat/route.ts's `ChatResponseBody` union
/// exactly, since this calls the literal same endpoints (see
/// apps/web/src/lib/ai/auth.ts for how those routes authenticate a
/// mobile Bearer-token caller alongside web's cookie session).
sealed class ChatResponse {
  const ChatResponse();
}

class ChatTextResponse extends ChatResponse {
  const ChatTextResponse({required this.text, required this.messages});
  final String text;
  final List<dynamic> messages;
}

class ChatToolConfirmation extends ChatResponse {
  const ChatToolConfirmation({
    required this.toolUseId,
    required this.toolName,
    required this.input,
    required this.confirmationToken,
    required this.messages,
  });
  final String toolUseId;
  final String toolName;
  final Map<String, dynamic> input;
  final String confirmationToken;
  final List<dynamic> messages;
}

class ChatErrorResponse extends ChatResponse {
  const ChatErrorResponse(this.error);
  final String error;
}

abstract interface class AiGateway {
  Future<ChatResponse> sendMessage({
    required List<dynamic> messages,
    required String accountId,
  });

  Future<ChatResponse> confirmTool({
    required List<dynamic> messages,
    required String toolUseId,
    required String confirmationToken,
    required bool approve,
    required String accountId,
  });
}

class AiRepository implements AiGateway {
  AiRepository(this._client);

  final SupabaseClient _client;

  Uri get _chatUri => Uri.parse('${AppConfig.webBaseUrl}/api/ai/chat');
  Uri get _confirmUri => Uri.parse('${AppConfig.webBaseUrl}/api/ai/confirm');

  Map<String, String> get _headers {
    final token = _client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<ChatResponse> sendMessage({
    required List<dynamic> messages,
    required String accountId,
  }) {
    return _post(_chatUri, {'messages': messages, 'accountId': accountId});
  }

  @override
  Future<ChatResponse> confirmTool({
    required List<dynamic> messages,
    required String toolUseId,
    required String confirmationToken,
    required bool approve,
    required String accountId,
  }) {
    return _post(_confirmUri, {
      'messages': messages,
      'toolUseId': toolUseId,
      'confirmationToken': confirmationToken,
      'approve': approve,
      'accountId': accountId,
    });
  }

  Future<ChatResponse> _post(Uri uri, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      return ChatErrorResponse(
        'Could not reach LOOP. Check your connection and try again.',
      );
    }

    if (response.statusCode == 503) {
      return const ChatErrorResponse(
        "AI isn't configured yet. See docs/KNOWN_ISSUES.md.",
      );
    }

    return parseAiGatewayResponse(response.statusCode, response.body);
  }
}

ChatResponse parseAiGatewayResponse(int statusCode, String responseBody) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseBody);
  } catch (_) {
    return ChatErrorResponse('Unexpected response ($statusCode).');
  }
  if (decoded is! Map<String, dynamic>) {
    return ChatErrorResponse('Unexpected response ($statusCode).');
  }

  final type = decoded['type'];
  if (type == 'error') {
    final error = decoded['error'];
    return ChatErrorResponse(
      error is String && error.trim().isNotEmpty
          ? error
          : 'Something went wrong. Try again.',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return ChatErrorResponse('Unexpected response ($statusCode).');
  }

  switch (type) {
    case 'text':
      final text = decoded['text'];
      final messages = decoded['messages'];
      if (text is! String || messages is! List<dynamic>) {
        return const ChatErrorResponse(
          'LOOP returned an invalid response. Try again.',
        );
      }
      return ChatTextResponse(text: text, messages: messages);
    case 'tool_confirmation':
      final toolUseId = decoded['toolUseId'];
      final toolName = decoded['toolName'];
      final input = decoded['input'];
      final confirmationToken = decoded['confirmationToken'];
      final messages = decoded['messages'];
      if (toolUseId is! String ||
          toolUseId.trim().isEmpty ||
          toolName is! String ||
          toolName.trim().isEmpty ||
          input is! Map<String, dynamic> ||
          confirmationToken is! String ||
          confirmationToken.trim().isEmpty ||
          messages is! List<dynamic>) {
        return const ChatErrorResponse(
          'This pending action is no longer valid. Ask LOOP again.',
        );
      }
      return ChatToolConfirmation(
        toolUseId: toolUseId,
        toolName: toolName,
        input: input,
        confirmationToken: confirmationToken,
        messages: messages,
      );
    default:
      return const ChatErrorResponse(
        'LOOP returned an invalid response. Try again.',
      );
  }
}

final aiGatewayProvider = Provider<AiGateway>(
  (ref) => AiRepository(ref.watch(supabaseClientProvider)),
);
