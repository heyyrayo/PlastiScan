import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/plastiscan_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'Are you sure you want to log out of your PlastiScan account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      // GoRouter's auth listener will also redirect to /login.
      context.go('/login');
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not log out. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    final textTheme = Theme.of(context).textTheme;

    final user = Supabase.instance.client.auth.currentUser;

    final fullName = user?.userMetadata?['full_name'] as String?;

    final displayName = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : 'PlastiScan Member';

    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cs.primary,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.gradientStart,
                      colors.gradientEnd,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const ProfileAvatar(radius: 40),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isNotEmpty ? email : 'PlastiScan Member',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Stats row ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const _StatCard(
                    label: 'Total Scans',
                    value: '0',
                  ),
                  const SizedBox(width: 12),
                  const _StatCard(
                    label: 'Safe Items',
                    value: '0',
                  ),
                  const SizedBox(width: 12),
                  const _StatCard(
                    label: 'High Risk',
                    value: '0',
                  ),
                ],
              ),
            ),
          ),

          // ── Settings title ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Settings',
                style: textTheme.titleMedium,
              ),
            ),
          ),

          // ── Settings list ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),

                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.shield_outlined,
                  label: 'Privacy & Data',
                  onTap: () => context.push('/privacy-data'),
                ),

                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () => context.push('/about'),
                ),

                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About PlastiScan',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // ── Logout ───────────────────────────────────────
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  iconColor: cs.error,
                  textColor: cs.error,
                  onTap: () => _logout(context),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? cs.primary,
          size: 22,
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
              ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: cs.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
