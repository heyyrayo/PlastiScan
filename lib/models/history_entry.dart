import 'scan_result.dart';

/// Groups history entries by time period for the timeline view.
class HistoryEntry {
  const HistoryEntry({
    required this.period,
    required this.results,
  });

  final String period; // e.g. 'Today', 'This Week', 'Earlier'
  final List<ScanResult> results;
}
