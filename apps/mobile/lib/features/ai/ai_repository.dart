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

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return ChatErrorResponse('Unexpected response (${response.statusCode}).');
    }

    switch (json['type']) {
      case 'text':
        return ChatTextResponse(
          text: json['text'] as String? ?? '',
          messages: (json['messages'] as List<dynamic>?) ?? const [],
        );
      case 'tool_confirmation':
        final confirmationToken = json['confirmationToken'] as String?;
        if (confirmationToken == null || confirmationToken.isEmpty) {
          return const ChatErrorResponse(
            'This pending action is no longer valid. Ask LOOP again.',
          );
        }
        return ChatToolConfirmation(
          toolUseId: json['toolUseId'] as String,
          toolName: json['toolName'] as String,
          input: (json['input'] as Map<String, dynamic>?) ?? const {},
          confirmationToken: confirmationToken,
          messages: (json['messages'] as List<dynamic>?) ?? const [],
        );
      case 'error':
        return ChatErrorResponse(
          json['error'] as String? ?? 'Something went wrong.',
        );
      default:
        return const ChatErrorResponse('Unexpected response.');
    }
  }
}

final aiGatewayProvider = Provider<AiGateway>(
  (ref) => AiRepository(ref.watch(supabaseClientProvider)),
);
