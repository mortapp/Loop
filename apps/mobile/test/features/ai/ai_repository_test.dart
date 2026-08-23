import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/ai/ai_repository.dart';

void main() {
  test(
    'valid tool confirmation is parsed without changing its binding data',
    () {
      final result = parseAiGatewayResponse(
        200,
        jsonEncode({
          'type': 'tool_confirmation',
          'toolUseId': 'tool-1',
          'toolName': 'create_action',
          'input': {'title': 'Follow up'},
          'confirmationToken': 'signed-token',
          'messages': [],
        }),
      );

      expect(result, isA<ChatToolConfirmation>());
      final confirmation = result as ChatToolConfirmation;
      expect(confirmation.toolUseId, 'tool-1');
      expect(confirmation.toolName, 'create_action');
      expect(confirmation.input, {'title': 'Follow up'});
      expect(confirmation.confirmationToken, 'signed-token');
    },
  );

  for (final malformed in <Map<String, dynamic>>[
    {
      'toolName': 'create_action',
      'input': <String, dynamic>{},
      'confirmationToken': 'signed-token',
      'messages': <dynamic>[],
    },
    {
      'toolUseId': 'tool-1',
      'toolName': 42,
      'input': <String, dynamic>{},
      'confirmationToken': 'signed-token',
      'messages': <dynamic>[],
    },
    {
      'toolUseId': 'tool-1',
      'toolName': 'create_action',
      'input': <dynamic>[],
      'confirmationToken': 'signed-token',
      'messages': <dynamic>[],
    },
    {
      'toolUseId': 'tool-1',
      'toolName': 'create_action',
      'input': <String, dynamic>{},
      'confirmationToken': '',
      'messages': <dynamic>[],
    },
    {
      'toolUseId': 'tool-1',
      'toolName': 'create_action',
      'input': <String, dynamic>{},
      'confirmationToken': 'signed-token',
      'messages': <String, dynamic>{},
    },
  ]) {
    test('malformed tool confirmation fails closed: $malformed', () {
      final result = parseAiGatewayResponse(
        200,
        jsonEncode({'type': 'tool_confirmation', ...malformed}),
      );

      expect(result, isA<ChatErrorResponse>());
      expect(
        (result as ChatErrorResponse).error,
        'This pending action is no longer valid. Ask LOOP again.',
      );
    });
  }

  test('malformed text response fails closed', () {
    final result = parseAiGatewayResponse(
      200,
      jsonEncode({'type': 'text', 'text': 7, 'messages': []}),
    );

    expect(result, isA<ChatErrorResponse>());
  });

  test('successful payload with a failing status is rejected', () {
    final result = parseAiGatewayResponse(
      500,
      jsonEncode({'type': 'text', 'text': 'Done', 'messages': []}),
    );

    expect(result, isA<ChatErrorResponse>());
    expect((result as ChatErrorResponse).error, 'Unexpected response (500).');
  });
}
