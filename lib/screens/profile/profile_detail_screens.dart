import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/plastiscan_colors.dart';
import '../../widgets/app_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileDetailScaffold(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      child: _EmptyNotificationState(),
    );
  }
}

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailScaffold(
      title: 'Privacy & Data',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoSection(
            title: 'Account Data',
            body:
                'PlastiScan uses your Supabase account to authenticate you and associate your scans with your account.',
          ),
          _InfoSection(
            title: 'Scan Data',
            body:
                'Scan results are used to show your analysis history. Review your saved results from the History section.',
          ),
          _InfoSection(
            title: 'Image Storage',
            body:
                'Images selected for analysis may be compressed and uploaded to the Supabase scan-images storage bucket for the analysis flow.',
          ),
          _InfoSection(
            title: 'Data Controls',
            body:
                'Account deletion and scan deletion controls are not currently available in the app. Contact the project maintainer for data requests.',
          ),
        ],
      ),
    );
  }
}

class AboutPlastiScanScreen extends StatelessWidget {
  const AboutPlastiScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _ProfileDetailScaffold(
      title: 'About PlastiScan',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          Image.asset('assets/logo/plastiscan_icon_transparent.png',
              width: 72, height: 72),
          const SizedBox(height: 16),
          Text('PlastiScan', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'AI-powered plastic identification and safety analysis.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          const _InfoSection(
              title: 'Purpose',
              body:
                  'PlastiScan helps you identify plastic materials and review an analysis of their safety profile.'),
          const _InfoSection(
              title: 'Technology',
              body:
                  'The app combines camera or manual product input with its connected analysis service.'),
          const _InfoSection(title: 'Version', body: '1.0.0+1'),
        ],
      ),
    );
  }
}

class _ProfileDetailScaffold extends StatelessWidget {
  const _ProfileDetailScaffold({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.mintAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text("You're all caught up",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'No new notifications right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
