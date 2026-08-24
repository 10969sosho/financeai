import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/voice_service.dart';
import '../../services/image_service.dart';

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

  // Voice input state
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  String _voicePartialText = '';
  Timer? _voiceSilenceTimer;

  // Image capture state
  File? _capturedImage;
  String _imageDescription = '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _voiceSilenceTimer?.cancel();
    _voiceService.dispose();
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

  // ─── Voice Recording ────────────────────────────────────────────

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopVoiceRecording();
    } else {
      await _startVoiceRecording();
    }
  }

  Future<void> _startVoiceRecording() async {
    final initialized = await _voiceService.initialize();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin mikrofon tidak diberikan. Silakan aktifkan di Pengaturan.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _voicePartialText = '';
    });

    _focusNode.unfocus();

    await _voiceService.startListening(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            _voicePartialText = text;
          });
          _resetSilenceTimer();
        }
      },
    );
  }

  Future<void> _stopVoiceRecording() async {
    _voiceSilenceTimer?.cancel();
    await _voiceService.stopListening();

    if (mounted) {
      setState(() {
        _isRecording = false;
      });

      // Put transcribed text into text field for user review
      if (_voicePartialText.isNotEmpty) {
        _controller.text = _voicePartialText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
      _voicePartialText = '';
    }
  }

  void _resetSilenceTimer() {
    _voiceSilenceTimer?.cancel();
    _voiceSilenceTimer = Timer(const Duration(seconds: 30), () {
      if (_isRecording) {
        _stopVoiceRecording();
      }
    });
  }

  // ─── Image Capture ──────────────────────────────────────────────

  void _showImageSourceSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Foto Struk'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage(fromCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage(fromCamera: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage({required bool fromCamera}) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final imageService = ImageService(apiClient.dio);

      final File? image = fromCamera
          ? await imageService.takePhoto()
          : await imageService.pickFromGallery();

      if (image != null && mounted) {
        setState(() {
          _capturedImage = image;
        });
        _focusNode.unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fromCamera
                  ? 'Gagal mengambil foto. Pastikan izin kamera diberikan.'
                  : 'Gagal memilih gambar.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeCapturedImage() {
    setState(() {
      _capturedImage = null;
      _imageDescription = '';
    });
  }

  // ─── Send Message ───────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (_isSending) return;

    final hasImage = _capturedImage != null;
    final body = text.trim();

    if (body.isEmpty && !hasImage) return;

    final imageToSend = _capturedImage;
    final description = _imageDescription.trim();

    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _isSending = true;
      _capturedImage = null;
      _imageDescription = '';
    });

    try {
      // Build content for optimistic message
      final displayContent =
          hasImage && body.isNotEmpty ? body : (body.isNotEmpty ? body : '📷 Foto struk');

      // Create optimistic user message
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        role: 'user',
        content: displayContent,
        status: 'completed',
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(userMessage);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();

      // Send to API - if image present, use multipart
      final responseMsg = await _sendMessageWithImage(
        body: body,
        imageFile: imageToSend,
        description: description.isNotEmpty ? description : null,
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
              onPressed: () {
                if (body.isNotEmpty) _sendMessage(body);
              },
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

  Future<Message> _sendMessageWithImage({
    required String body,
    File? imageFile,
    String? description,
  }) async {
    final apiClient = ref.read(apiClientProvider);

    if (imageFile != null) {
      // Use Dio to send multipart with image
      final formData = await _buildChatFormData(
        body: body,
        imageFile: imageFile,
        description: description,
      );

      final response = await apiClient.dio.post(
        '/chat',
        data: formData,
      );

      final messageData =
          response.data['data']['message'] as Map<String, dynamic>;
      return Message.fromJson(messageData);
    } else {
      // Plain text message
      final chatService = ref.read(chatServiceProvider);
      return await chatService.sendMessage(
        body,
        sessionId: widget.sessionId,
      );
    }
  }

  Future<dynamic> _buildChatFormData({
    required String body,
    required File imageFile,
    String? description,
  }) async {
    final imageBytes = await imageFile.readAsBytes();

    return {
      if (body.isNotEmpty) 'body': body,
      'session_id': widget.sessionId,
      'image': {
        'value': imageBytes,
        'filename':
            'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'contentType': 'image/jpeg',
      },
      if (description != null) 'image_description': description,
    };
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

          // Image preview
          if (_capturedImage != null)
            _ImagePreview(
              imageFile: _capturedImage!,
              description: _imageDescription,
              onDescriptionChanged: (val) {
                setState(() => _imageDescription = val);
              },
              onRemove: _removeCapturedImage,
            ),

          // Input area
          SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: bottomPadding > 0 ? bottomPadding : 8,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Camera button
                  IconButton(
                    onPressed: _showImageSourceSheet,
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Ambil foto struk',
                  ),

                  // Mic button / recording indicator
                  if (_isRecording)
                    IconButton(
                      onPressed: _stopVoiceRecording,
                      icon: _PulsingMicIcon(colorScheme: colorScheme),
                      tooltip: 'Berhenti merekam',
                    )
                  else
                    IconButton(
                      onPressed: _toggleVoiceRecording,
                      icon: Icon(
                        Icons.mic_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Input suara',
                    ),

                  // Text field
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _isRecording
                              ? 'Mendengarkan...'
                              : 'Ketik pesan...',
                          hintStyle: TextStyle(
                            color: _isRecording
                                ? colorScheme.error.withValues(alpha: 0.7)
                                : colorScheme.onSurfaceVariant
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
                      onPressed: _canSend()
                          ? () => _sendMessage(_controller.text)
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: _canSend()
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        foregroundColor: _canSend()
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
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

  bool _canSend() {
    if (_isSending || _isRecording) return false;
    if (_controller.text.trim().isNotEmpty) return true;
    if (_capturedImage != null) return true;
    return false;
  }
}

// ─── Pulsing Mic Icon ──────────────────────────────────────────
class _PulsingMicIcon extends StatefulWidget {
  final ColorScheme colorScheme;

  const _PulsingMicIcon({required this.colorScheme});

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.colorScheme.error
                .withValues(alpha: _animation.value * 0.2),
          ),
          child: Icon(
            Icons.mic,
            color: widget.colorScheme.error,
            size: 22,
          ),
        );
      },
    );
  }
}

// ─── Image Preview ─────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final File imageFile;
  final String description;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onRemove;

  const _ImagePreview({
    required this.imageFile,
    required this.description,
    required this.onDescriptionChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.file(
                      imageFile,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.error,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: colorScheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: onDescriptionChanged,
                  decoration: InputDecoration(
                    hintText: 'Tambah deskripsi struk (opsional)...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                ),
              ),
            ],
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
