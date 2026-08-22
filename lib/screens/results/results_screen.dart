import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/scan_result.dart';
import '../../models/risk_level.dart';
import '../../theme/plastiscan_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buttons/app_buttons.dart';
import '../../widgets/risk_indicator.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, this.result});

  final ScanResult? result;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;

  ScanResult get _result => widget.result ?? _stubResult;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _ringScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack),
    );
    _ringOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _entryCtrl.forward());
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<PlastiScanColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final result = _result;

    final detailCards = _buildDetailCards(result, context, colors);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analysis Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              // TODO(engineer): implement share via platform share sheet
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Risk ring + score ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: FadeTransition(
                  opacity: _ringOpacity,
                  child: ScaleTransition(
                    scale: _ringScale,
                    child: RiskCircularIndicator(
                      level: result.riskLevel,
                      score: result.riskScore ?? 0,
                      size: 220,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Product name + scan ID ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.productName,
                      style: textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    result.id,
                    style: textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Chemical codes row ────────────────────────────────────────────
          if (result.chemicalCodes.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.chemicalCodes
                      .map((code) => _CodeChip(code: code))
                      .toList(),
                ),
              ),
            ),

          // ── Detail cards (staggered fade-in) ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _StaggeredCard(
                  delay: Duration(milliseconds: 100 + i * 60),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: detailCards[i],
                  ),
                ),
                childCount: detailCards.length,
              ),
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Scan Another Item',
                      onPressed: () => context.go('/scan'),
                      leadingIcon: Icons.qr_code_scanner_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      label: 'View Full Report',
                      onPressed: () {
                        // TODO(engineer): expand full chemical breakdown report
                      },
                      leadingIcon: Icons.description_outlined,
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

  List<Widget> _buildDetailCards(
      ScanResult r, BuildContext context, PlastiScanColors colors) {
    return [
      ResultDetailCard(
        icon: Icons.science_rounded,
        title: 'Plastic Type',
        body: r.plasticType,
        trailing: Text(
          r.plasticType,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      ResultDetailCard(
        icon: Icons.thermostat_rounded,
        title: 'Heat Resistance',
        body: 'Suitable up to 70°C — do not microwave',
        iconColor: colors.riskMedium,
      ),
      ResultDetailCard(
        icon: Icons.water_drop_outlined,
        title: 'Chemical Leaching',
        body: r.riskLevel == RiskLevel.low
            ? 'No significant leaching detected at normal conditions'
            : 'Potential leaching detected — avoid prolonged contact with hot liquids',
        iconColor: r.riskLevel == RiskLevel.high
            ? colors.riskHigh
            : colors.riskLow,
      ),
      ResultDetailCard(
        icon: Icons.recycling_rounded,
        title: 'Recyclability',
        body: 'Check local guidelines — most ${r.plasticType} is accepted',
        iconColor: colors.riskLow,
      ),
      if (r.notes != null)
        ResultDetailCard(
          icon: Icons.notes_rounded,
          title: 'Notes',
          body: r.notes!,
        ),
    ];
  }
}

// ─── Code chip ───────────────────────────────────────────────────────────────
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: cs.primary),
      ),
    );
  }
}

// ─── Staggered entrance card ──────────────────────────────────────────────────
class _StaggeredCard extends StatefulWidget {
  const _StaggeredCard({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Stub result for preview ──────────────────────────────────────────────────
final _stubResult = ScanResult(
  id: 'SCAN-001',
  productName: 'Water Bottle',
  plasticType: 'PET-1',
  riskLevel: RiskLevel.low,
  scannedAt: DateTime.now(),
  riskScore: 2.1,
  chemicalCodes: ['BPA-FREE', 'PET-1', 'FDA-APPROVED'],
  notes: null,
);
