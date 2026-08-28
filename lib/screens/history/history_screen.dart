import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/history_entry.dart';
import '../../models/risk_level.dart';
import '../../models/scan_result.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_chip.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  final _filters = ['All', 'Low Risk', 'Medium Risk', 'High Risk'];
  String _activeFilter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HistoryEntry> get _entries {
    final all = _stubEntries();
    return all
        .map((group) {
          final filtered = group.results.where((r) {
            final matchesQuery = _query.isEmpty ||
                r.productName.toLowerCase().contains(_query.toLowerCase()) ||
                r.plasticType.toLowerCase().contains(_query.toLowerCase());
            final matchesFilter =
                _activeFilter == 'All' || r.riskLevel.label == _activeFilter;
            return matchesQuery && matchesFilter;
          }).toList();
          return HistoryEntry(period: group.period, results: filtered);
        })
        .where((g) => g.results.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: CustomScrollView(
        slivers: [
          // ── Sticky search + filter header ─────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchFilterDelegate(
              searchCtrl: _searchCtrl,
              filters: _filters,
              activeFilter: _activeFilter,
              onFilterChanged: (f) => setState(() => _activeFilter = f),
            ),
          ),

          if (entries.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 64, color: cs.outlineVariant),
                    const SizedBox(height: 16),
                    Text('No results found',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Try a different search or filter',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            for (final group in entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    group.period,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TimelineItemCard(
                        result: group.results[i],
                        onTap: () =>
                            context.push('/results', extra: group.results[i]),
                      ),
                    ),
                    childCount: group.results.length,
                  ),
                ),
              ),
            ],

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<HistoryEntry> _stubEntries() => [
        HistoryEntry(
          period: 'Today',
          results: [
            ScanResult(
              id: 'S001',
              productName: 'Water Bottle',
              plasticType: 'PET-1',
              riskLevel: RiskLevel.low,
              scannedAt: DateTime.now(),
              riskScore: 1.8,
            ),
            ScanResult(
              id: 'S002',
              productName: 'Shampoo Bottle',
              plasticType: 'HDPE-2',
              riskLevel: RiskLevel.low,
              scannedAt: DateTime.now(),
              riskScore: 2.3,
            ),
          ],
        ),
        HistoryEntry(
          period: 'This Week',
          results: [
            ScanResult(
              id: 'S003',
              productName: 'Food Container',
              plasticType: 'PP-5',
              riskLevel: RiskLevel.medium,
              scannedAt: DateTime.now().subtract(const Duration(days: 3)),
              riskScore: 5.0,
            ),
            ScanResult(
              id: 'S004',
              productName: 'Cling Wrap',
              plasticType: 'PVC-3',
              riskLevel: RiskLevel.high,
              scannedAt: DateTime.now().subtract(const Duration(days: 5)),
              riskScore: 8.1,
            ),
          ],
        ),
        HistoryEntry(
          period: 'Earlier',
          results: [
            ScanResult(
              id: 'S005',
              productName: 'Plastic Bag',
              plasticType: 'LDPE-4',
              riskLevel: RiskLevel.unknown,
              scannedAt: DateTime.now().subtract(const Duration(days: 14)),
              riskScore: 0,
            ),
          ],
        ),
      ];
}

// ─── Sliver header for search + filter ───────────────────────────────────────
class _SearchFilterDelegate extends SliverPersistentHeaderDelegate {
  const _SearchFilterDelegate({
    required this.searchCtrl,
    required this.filters,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final TextEditingController searchCtrl;
  final List<String> filters;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  double get minExtent => 120;
  @override
  double get maxExtent => 120;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search history…',
              prefixIcon:
                  Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => searchCtrl.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => AppFilterChip(
                label: filters[i],
                selected: activeFilter == filters[i],
                onTap: () => onFilterChanged(filters[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchFilterDelegate old) =>
      old.activeFilter != activeFilter || old.searchCtrl != searchCtrl;
}
