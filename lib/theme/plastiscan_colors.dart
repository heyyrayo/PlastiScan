import 'package:flutter/material.dart';

/// PlastiScan semantic colour extension — risk levels and brand tokens
/// that don't map cleanly into Material 3's [ColorScheme] slots.
@immutable
class PlastiScanColors extends ThemeExtension<PlastiScanColors> {
  const PlastiScanColors({
    required this.riskLow,
    required this.riskLowBg,
    required this.riskMedium,
    required this.riskMediumBg,
    required this.riskHigh,
    required this.riskHighBg,
    required this.riskUnknown,
    required this.riskUnknownBg,
    required this.gradientStart,
    required this.gradientEnd,
    required this.mintAccent,
    required this.softSage,
  });

  final Color riskLow;
  final Color riskLowBg;
  final Color riskMedium;
  final Color riskMediumBg;
  final Color riskHigh;
  final Color riskHighBg;
  final Color riskUnknown;
  final Color riskUnknownBg;

  /// Primary gradient: #1F6F5C → #2E8B57 at 135°
  final Color gradientStart;
  final Color gradientEnd;

  /// Mint (#59D39B) — scan bracket pulse colour
  final Color mintAccent;

  /// Soft Sage (#B8E6D2) — list dividers, secondary button bg
  final Color softSage;

  static const PlastiScanColors light = PlastiScanColors(
    riskLow: Color(0xFF2E7D32),
    riskLowBg: Color(0xFFE8F5E9),
    riskMedium: Color(0xFFF9A825),
    riskMediumBg: Color(0xFFFFF8E1),
    riskHigh: Color(0xFFD32F2F),
    riskHighBg: Color(0xFFFDECEA),
    riskUnknown: Color(0xFF78909C),
    riskUnknownBg: Color(0xFFECEFF1),
    gradientStart: Color(0xFF1F6F5C),
    gradientEnd: Color(0xFF2E8B57),
    mintAccent: Color(0xFF59D39B),
    softSage: Color(0xFFB8E6D2),
  );

  @override
  PlastiScanColors copyWith({
    Color? riskLow, Color? riskLowBg,
    Color? riskMedium, Color? riskMediumBg,
    Color? riskHigh, Color? riskHighBg,
    Color? riskUnknown, Color? riskUnknownBg,
    Color? gradientStart, Color? gradientEnd,
    Color? mintAccent, Color? softSage,
  }) => PlastiScanColors(
    riskLow: riskLow ?? this.riskLow,
    riskLowBg: riskLowBg ?? this.riskLowBg,
    riskMedium: riskMedium ?? this.riskMedium,
    riskMediumBg: riskMediumBg ?? this.riskMediumBg,
    riskHigh: riskHigh ?? this.riskHigh,
    riskHighBg: riskHighBg ?? this.riskHighBg,
    riskUnknown: riskUnknown ?? this.riskUnknown,
    riskUnknownBg: riskUnknownBg ?? this.riskUnknownBg,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    mintAccent: mintAccent ?? this.mintAccent,
    softSage: softSage ?? this.softSage,
  );

  @override
  PlastiScanColors lerp(PlastiScanColors? other, double t) {
    if (other == null) return this;
    return PlastiScanColors(
      riskLow: Color.lerp(riskLow, other.riskLow, t)!,
      riskLowBg: Color.lerp(riskLowBg, other.riskLowBg, t)!,
      riskMedium: Color.lerp(riskMedium, other.riskMedium, t)!,
      riskMediumBg: Color.lerp(riskMediumBg, other.riskMediumBg, t)!,
      riskHigh: Color.lerp(riskHigh, other.riskHigh, t)!,
      riskHighBg: Color.lerp(riskHighBg, other.riskHighBg, t)!,
      riskUnknown: Color.lerp(riskUnknown, other.riskUnknown, t)!,
      riskUnknownBg: Color.lerp(riskUnknownBg, other.riskUnknownBg, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      mintAccent: Color.lerp(mintAccent, other.mintAccent, t)!,
      softSage: Color.lerp(softSage, other.softSage, t)!,
    );
  }
}
