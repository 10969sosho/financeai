import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? _user;
  bool _isLoading = true;
  String? _error;
  bool _notifEnabled = false;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authServiceProvider).getMe();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data profil';
          _isLoading = false;
        });
      }
    }
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _showLogoutDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Keluar',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        await ref.read(authStateProvider.notifier).logout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchUser,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text(_error!, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _fetchUser,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    children: [
                      // ── Profile Header ──
                      _buildProfileHeader(theme, colorScheme),
                      const SizedBox(height: 32),

                      // ── Settings Section ──
                      _buildSectionTitle(theme, 'Pengaturan'),
                      const SizedBox(height: 8),
                      _buildSettingsCard(theme, colorScheme),
                      const SizedBox(height: 32),

                      // ── About Section ──
                      _buildSectionTitle(theme, 'Tentang'),
                      const SizedBox(height: 8),
                      _buildAboutCard(theme, colorScheme),
                      const SizedBox(height: 32),

                      // ── Logout Button ──
                      _buildLogoutButton(colorScheme),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }

  // ── Profile Header ──────────────────────────────────────────

  Widget _buildProfileHeader(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              _initials(_user?.name ?? ''),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _user?.name ?? '-',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?.email ?? '-',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Title ───────────────────────────────────────────

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Settings Card ───────────────────────────────────────────

  Widget _buildSettingsCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Notifikasi toggle
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifikasi',
            trailing: Switch(
              value: _notifEnabled,
              onChanged: (v) => setState(() => _notifEnabled = v),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          // Bahasa
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Bahasa',
            trailing: Text(
              'Indonesia',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          // Tema
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tema',
            trailing: Text(
              'Terang',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── About Card ──────────────────────────────────────────────

  Widget _buildAboutCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Tentang FinanceAI',
            trailing: Text(
              'v1.0.0',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Syarat & Ketentuan',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Kebijakan Privasi',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout Button ───────────────────────────────────────────

  Widget _buildLogoutButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Keluar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Settings Tile ──────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
