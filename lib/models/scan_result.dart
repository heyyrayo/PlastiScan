import 'package:flutter/material.dart';
import 'risk_level.dart';

/// Immutable model representing one completed scan.
@immutable
class ScanResult {
  const ScanResult({
    required this.id,
    required this.productName,
    required this.plasticType,
    required this.riskLevel,
    required this.scannedAt,
    this.imageUrl,
    this.chemicalCodes = const [],
    this.riskScore,
    this.notes,
  });

  final String id;
  final String productName;
  final String plasticType;    // e.g. 'PET', 'HDPE', 'PVC'
  final RiskLevel riskLevel;
  final DateTime scannedAt;
  final String? imageUrl;
  final List<String> chemicalCodes;
  final double? riskScore;      // 0.0 – 10.0
  final String? notes;
}
