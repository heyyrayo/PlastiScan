/// Risk level enum — used throughout the app for scan results.
/// Every risk indicator must include both an icon and a text label (accessibility requirement).
enum RiskLevel { low, medium, high, unknown }

extension RiskLevelX on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:     return 'Low Risk';
      case RiskLevel.medium:  return 'Medium Risk';
      case RiskLevel.high:    return 'High Risk';
      case RiskLevel.unknown: return 'Unknown';
    }
  }

  String get shortLabel {
    switch (this) {
      case RiskLevel.low:     return 'Low';
      case RiskLevel.medium:  return 'Medium';
      case RiskLevel.high:    return 'High';
      case RiskLevel.unknown: return 'Unknown';
    }
  }

  String get icon {
    switch (this) {
      case RiskLevel.low:     return '✓';
      case RiskLevel.medium:  return '!';
      case RiskLevel.high:    return '✕';
      case RiskLevel.unknown: return '?';
    }
  }
}
