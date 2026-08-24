import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/chat_session.dart';
import '../../services/chat_service.dart';
import 'chat_detail_screen.dart';

final sessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final chatService = ref.read(chatServiceProvider);
  return chatService.getSessions();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSession(context, ref),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Baru'),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sessionsProvider);
          await ref.read(sessionsProvider.future);
        },
        child: sessionsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: colorScheme.error.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat sesi',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tarik ke bawah untuk mencoba lagi',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(sessionsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return _EmptyState(
                colorScheme: colorScheme,
                theme: theme,
                onNewSession: () => _createSession(context, ref),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 100),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionTile(
                  session: session,
                  onDelete: () => _deleteSession(context, ref, session),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          sessionId: session.id,
                          sessionTitle: session.title,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final session = await chatService.createSession();
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              sessionId: session.id,
              sessionTitle: session.title,
            ),
          ),
        );
      }
      ref.invalidate(sessionsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat sesi: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSession(
      BuildContext context, WidgetRef ref, ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: const Text('Hapus Sesi?'),
        content: Text(
          'Sesi "${session.title ?? 'Tanpa Judul'}" akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Hapus',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final chatService = ref.read(chatServiceProvider);
        await chatService.deleteSession(session.id);
        ref.invalidate(sessionsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus sesi: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

// ─── Session Tile ──────────────────────────────────────────────
class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.error.withValues(alpha: 0.1),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.error,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          session.title ?? 'Sesi Baru',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatLastMessageTime(session.lastMessageAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatLastMessageTime(DateTime? time) {
    if (time == null) return 'Belum ada pesan';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays == 0) return DateFormat('HH:mm').format(time);
    if (diff.inDays == 1) return 'Kemarin, ${DateFormat('HH:mm').format(time)}';
    if (diff.inDays < 7) {
      final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      return '${dayNames[time.weekday - 1]}, ${DateFormat('HH:mm').format(time)}';
    }
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(time);
  }
}

// ─── Empty State ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onNewSession;

  const _EmptyState({
    required this.colorScheme,
    required this.theme,
    required this.onNewSession,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.18,
        ),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Text(
            'Belum ada percakapan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Mulai chat dengan AI untuk mencatat pengeluaran, mengecek saldo, atau melihat laporan keuangan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: FilledButton.icon(
            onPressed: onNewSession,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Mulai Chat'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
