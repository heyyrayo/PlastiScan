import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/app_navigation.dart';
import '../../models/risk_level.dart';
import '../../models/scan_result.dart';
import '../../theme/plastiscan_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/molecular_background.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/profile_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    final textTheme = Theme.of(context).textTheme;

    // Stub recent scans — replace with real Riverpod provider
    final recentScans = _stubRecentScans();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: cs.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.gradientStart, colors.gradientEnd],
                      ),
                    ),
                  ),
                  MolecularBackground(
                    nodeColor: Colors.white,
                    opacity: 0.07,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Good morning 👋',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'What will you\nscan today?',
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            leadingWidth: 176,
            leading: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo/plastiscan_icon_transparent.png',
                    width: 34,
                    height: 34,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'PlastiScan',
                      maxLines: 1,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ProfileAvatar(
                  radius: 18,
                  onTap: () => context.push('/profile'),
                ),
              ),
            ],
          ),

          // ── Quick action cards row ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan Item',
                          color: cs.primary,
                          onTap: () => goToScan(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.edit_rounded,
                          label: 'Manual Entry',
                          color: colors.gradientEnd,
                          onTap: () => goToManualEntry(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.history_rounded,
                          label: 'History',
                          color: cs.secondary,
                          onTap: () => context.go('/history'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Recent Analysis section ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Analysis', style: textTheme.titleMedium),
                  TextButton(
                    onPressed: () => context.go('/history'),
                    child: Text('See all',
                        style:
                            textTheme.labelMedium?.copyWith(color: cs.primary)),
                  ),
                ],
              ),
            ),
          ),

          if (recentScans.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonList(itemCount: 3),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final result = recentScans[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecentScanCard(
                        result: result,
                        animationDelay: Duration(milliseconds: i * 60),
                        onTap: () => context.push('/results', extra: result),
                      ),
                    );
                  },
                  childCount: recentScans.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<ScanResult> _stubRecentScans() => [
        ScanResult(
          id: 'S001',
          productName: 'Water Bottle',
          plasticType: 'PET-1',
          riskLevel: RiskLevel.low,
          scannedAt: DateTime.now().subtract(const Duration(hours: 2)),
          riskScore: 1.8,
          chemicalCodes: ['BPA-FREE', 'PET-1'],
        ),
        ScanResult(
          id: 'S002',
          productName: 'Food Container',
          plasticType: 'PP-5',
          riskLevel: RiskLevel.medium,
          scannedAt: DateTime.now().subtract(const Duration(days: 1)),
          riskScore: 5.2,
          chemicalCodes: ['PP-5', 'FOOD-SAFE'],
        ),
        ScanResult(
          id: 'S003',
          productName: 'Plastic Bag',
          plasticType: 'LDPE-4',
          riskLevel: RiskLevel.high,
          scannedAt: DateTime.now().subtract(const Duration(days: 2)),
          riskScore: 7.9,
          chemicalCodes: ['LDPE-4', 'PVC-ADJ'],
        ),
      ];
}

// ─── Quick action card ────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ─── Recent scan card ─────────────────────────────────────────────────────────
class _RecentScanCard extends StatefulWidget {
  const _RecentScanCard({
    required this.result,
    required this.animationDelay,
    required this.onTap,
  });

  final ScanResult result;
  final Duration animationDelay;
  final VoidCallback onTap;

  @override
  State<_RecentScanCard> createState() => _RecentScanCardState();
}

class _RecentScanCardState extends State<_RecentScanCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.animationDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: TimelineItemCard(
          result: widget.result,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
