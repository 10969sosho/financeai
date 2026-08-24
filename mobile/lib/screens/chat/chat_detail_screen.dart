import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String? sessionTitle;

  const ChatDetailScreen({
    super.key,
    required this.sessionId,
    this.sessionTitle,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final messages = await chatService.getMessages(widget.sessionId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        // Sort oldest first
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _scrollToBottom();
        _startPollingIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPollingIfNeeded() {
    final hasPending = _messages.any((m) => m.isPending);
    if (hasPending && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _pollForUpdates();
      });
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollForUpdates() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final messages = await chatService.getMessages(widget.sessionId);
      if (!mounted) return;

      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Check if any messages changed status
      bool changed = false;
      for (final newMsg in messages) {
        final existing = _messages.where((m) => m.id == newMsg.id);
        if (existing.isNotEmpty) {
          final old = existing.first;
          if (old.isPending && !newMsg.isPending) {
            changed = true;
          }
        }
      }

      if (changed) {
        setState(() => _messages = messages);
        _scrollToBottom();
      }

      // Stop polling if no more pending
      final stillPending = _messages.any((m) => m.isPending);
      if (!stillPending) {
        _stopPolling();
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final body = text.trim();
    _controller.clear();
    _focusNode.unfocus();

    setState(() => _isSending = true);

    try {
      final chatService = ref.read(chatServiceProvider);

      // Create optimistic user message
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        role: 'user',
        content: body,
        status: 'completed',
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(userMessage);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();

      // Send to API
      final responseMsg = await chatService.sendMessage(
        body,
        sessionId: widget.sessionId,
      );

      if (mounted) {
        setState(() {
          // Remove optimistic message, add real user message + pending assistant
          _messages.remove(userMessage);
          _messages.add(responseMsg);
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
        _startPollingIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pesan: $e'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: () => _sendMessage(body),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.sessionTitle ?? 'Chat',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _EmptyChat(
                        colorScheme: colorScheme,
                        theme: theme,
                        onSuggestionTap: _sendMessage,
                      )
                    : _MessagesList(
                        messages: _messages,
                        scrollController: _scrollController,
                      ),
          ),

          // Typing indicator
          if (_isSending || _messages.any((m) => m.isPending))
            const _TypingIndicator(),

          // Input area
          SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 8,
                top: 8,
                bottom: bottomPadding > 0 ? bottomPadding : 8,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Ketik pesan...',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: theme.textTheme.bodyMedium,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Send button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      onPressed: _controller.text.trim().isEmpty
                          ? null
                          : () => _sendMessage(_controller.text),
                      style: IconButton.styleFrom(
                        backgroundColor: _controller.text.trim().isEmpty
                            ? colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5)
                            : colorScheme.primary,
                        foregroundColor: _controller.text.trim().isEmpty
                            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                            : colorScheme.onPrimary,
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Messages List ──────────────────────────────────────────────
class _MessagesList extends StatelessWidget {
  final List<Message> messages;
  final ScrollController scrollController;

  const _MessagesList({
    required this.messages,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message.role == 'user';
        final showDateSeparator = index == 0 ||
            !_isSameDay(
              messages[index].createdAt,
              messages[index - 1].createdAt,
            );

        return Column(
          children: [
            if (showDateSeparator)
              _DateSeparator(date: message.createdAt),
            if (message.isFailed)
              _FailedMessage(message: message)
            else if (isUser)
              _UserBubble(message: message)
            else
              _AssistantBubble(message: message),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ─── User Bubble ────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final Message message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Assistant Bubble ───────────────────────────────────────────
class _AssistantBubble extends StatelessWidget {
  final Message message;

  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Failed Message ────────────────────────────────────────────
class _FailedMessage extends StatelessWidget {
  final Message message;

  const _FailedMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Gagal memproses',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Typing Indicator ──────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Opacity(
            opacity: _animation.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI sedang mengetik...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Date Separator ────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    String label;
    if (dateOnly == today) {
      label = 'Hari Ini';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      label = 'Kemarin';
    } else {
      label = DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ─── Empty Chat State ──────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final ValueChanged<String> onSuggestionTap;

  static const _suggestions = [
    'Tadi makan 25 ribu',
    'Berapa saldo saya?',
    'Laporan bulan ini',
  ];

  const _EmptyChat({
    required this.colorScheme,
    required this.theme,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.12,
        ),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Mulai percakapan dengan AI',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tanyakan tentang keuangan Anda atau catat transaksi harian.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Suggestion chips
        ..._suggestions.map(
          (suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onSuggestionTap(suggestion),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: colorScheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
