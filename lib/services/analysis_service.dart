// Stub services — TODO(engineer): wire real AI/camera integration here.
// Do not add fake network calls; provide only the API surface the UI needs.

import '../models/scan_result.dart';
import '../models/risk_level.dart';

class ScanService {
  // TODO(engineer): integrate real camera barcode/image-analysis pipeline here.
  /// Returns a stub [ScanResult] representing a successful scan.
  Future<ScanResult> analyzeCapture(String imagePath) async {
    await Future.delayed(const Duration(seconds: 3)); // simulate processing
    return ScanResult(
      id: 'SCAN-${DateTime.now().millisecondsSinceEpoch}',
      productName: 'Sample Bottle',
      plasticType: 'PET',
      riskLevel: RiskLevel.low,
      scannedAt: DateTime.now(),
      riskScore: 2.1,
      chemicalCodes: ['BPA-FREE', 'PET-1'],
    );
  }
}

class AnalysisService {
  // TODO(engineer): integrate real AI polymer analysis backend here.
  /// Runs analysis on a manual entry form submission.
  Future<ScanResult> analyzeManualEntry({
    required String productName,
    required String plasticCode,
    String? additionalNotes,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return ScanResult(
      id: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
      productName: productName,
      plasticType: plasticCode,
      riskLevel: RiskLevel.unknown,
      scannedAt: DateTime.now(),
      notes: additionalNotes,
    );
  }
}
