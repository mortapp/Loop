import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/account_sheet.dart';
import '../../core/widgets/loop_seal.dart';
import 'ai_repository.dart';

enum _EntryRole { user, assistant, system }

class _ChatEntry {
  const _ChatEntry(this.role, this.text);
  final _EntryRole role;
  final String text;
}

/// Real "Ask LOOP" chat client — calls the exact same
/// `/api/ai/chat` + `/api/ai/confirm` tool-registry backend apps/web's
/// chat UI calls (see apps/web/src/lib/ai/auth.ts), never a parallel
/// mobile-only AI path. Every tool call stops here for a human
/// Confirm/Decline before it executes — nothing runs unattended.
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatEntry> _entries = [];

  List<dynamic> _messages = const [];
  bool _sending = false;
  String? _error;
  ChatToolConfirmation? _pendingConfirmation;
  Future<ChatResponse> Function()? _retry;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final repo = AiRepository(ref.read(supabaseClientProvider));
    final accountId = ref.read(activeAccountProvider).id;
    final outgoing = [
      ..._messages,
      {'role': 'user', 'content': text},
    ];

    setState(() {
      _entries.add(_ChatEntry(_EntryRole.user, text));
      _messages = outgoing;
      _controller.clear();
      _sending = true;
      _error = null;
      _pendingConfirmation = null;
      _retry = () => repo.sendMessage(messages: outgoing, accountId: accountId);
    });
    _scrollToBottom();

    final result = await _retry!();
    _handleResult(result);
  }

  Future<void> _respondToConfirmation(bool approve) async {
    final confirmation = _pendingConfirmation;
    if (confirmation == null) return;

    final repo = AiRepository(ref.read(supabaseClientProvider));
    final accountId = ref.read(activeAccountProvider).id;
    final outgoingMessages = confirmation.messages;

    setState(() {
      _pendingConfirmation = null;
      _sending = true;
      _error = null;
      _entries.add(
        _ChatEntry(
          _EntryRole.system,
          approve
              ? 'Approved — ${_describeTool(confirmation)}'
              : 'Declined — ${_describeTool(confirmation)}',
        ),
      );
      _retry = () => repo.confirmTool(
        messages: outgoingMessages,
        toolUseId: confirmation.toolUseId,
        approve: approve,
        accountId: accountId,
      );
    });
    _scrollToBottom();

    final result = await _retry!();
    _handleResult(result);
  }

  void _handleResult(ChatResponse result) {
    if (!mounted) return;
    setState(() {
      _sending = false;
      switch (result) {
        case ChatTextResponse(:final text, :final messages):
          _messages = messages;
          if (text.isNotEmpty) {
            _entries.add(_ChatEntry(_EntryRole.assistant, text));
          }
        case ChatToolConfirmation confirmation:
          _messages = confirmation.messages;
          _pendingConfirmation = confirmation;
        case ChatErrorResponse(:final error):
          _error = error;
      }
    });
    _scrollToBottom();
  }

  Future<void> _retrySend() async {
    final retry = _retry;
    if (retry == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _handleResult(await retry());
  }

  String _describeTool(ChatToolConfirmation confirmation) {
    switch (confirmation.toolName) {
      case 'create_action':
        return 'create an action';
      case 'log_money_event':
        return 'log a money event';
      default:
        return confirmation.toolName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = _entries.isNotEmpty || _pendingConfirmation != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI'),
        actions: const [AccountAvatarButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: hasContent
                  ? ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount:
                          _entries.length +
                          (_pendingConfirmation != null ? 1 : 0) +
                          (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _entries.length) {
                          return _EntryBubble(entry: _entries[index]);
                        }
                        var remaining = index - _entries.length;
                        if (_pendingConfirmation != null) {
                          if (remaining == 0) {
                            return _ConfirmationCard(
                              confirmation: _pendingConfirmation!,
                              description: _describeTool(_pendingConfirmation!),
                              onApprove: () => _respondToConfirmation(true),
                              onDecline: () => _respondToConfirmation(false),
                            );
                          }
                          remaining -= 1;
                        }
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              LoopSeal(size: 20, keyPoint: false, opacity: 0.7),
                              SizedBox(width: AppSpacing.sm),
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.tyrianAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : _EmptyState(theme: theme),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.dangerText,
                        ),
                      ),
                    ),
                    if (_retry != null)
                      TextButton(
                        onPressed: _sending ? null : _retrySend,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      enabled: !_sending && _pendingConfirmation == null,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about a quote, return, or your day…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: (_sending || _pendingConfirmation != null)
                        ? null
                        : _send,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Ask LOOP',
          style: GoogleFonts.fraunces(
            textStyle: theme.textTheme.headlineMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'What should we work through? Nothing here executes without you approving it first.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LoopSeal(size: 32, keyPoint: false, opacity: 0.6),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Try asking LOOP to draft a follow-up action or log a money event — every action it proposes shows up here first for you to confirm or decline.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryBubble extends StatelessWidget {
  const _EntryBubble({required this.entry});
  final _ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entry.role == _EntryRole.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Center(
          child: Text(
            entry.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (entry.role == _EntryRole.user) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.tyrianDeep,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                entry.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onAccentFill,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: LoopSeal(size: 18, keyPoint: false),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(entry.text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.confirmation,
    required this.description,
    required this.onApprove,
    required this.onDecline,
  });

  final ChatToolConfirmation confirmation;
  final String description;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = confirmation.input.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Card(
        color: AppColors.surfaceRaised,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LoopSeal(size: 18, keyPoint: false),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'LOOP wants to $description',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: onApprove,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
