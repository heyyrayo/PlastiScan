import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'plastiscan_colors.dart';

// ─── Colour constants ───────────────────────────────────────────────────────
const _primary               = Color(0xFF005645);
const _primaryContainer      = Color(0xFF1F6F5C);
const _onPrimary             = Color(0xFFFFFFFF);
const _onPrimaryContainer    = Color(0xFFA3EFD7);
const _secondary             = Color(0xFF3C6657);
const _onSecondary           = Color(0xFFFFFFFF);
const _secondaryContainer    = Color(0xFFBEEDD8);
const _onSecondaryContainer  = Color(0xFF426D5D);
const _tertiary              = Color(0xFF005730);
const _onTertiary            = Color(0xFFFFFFFF);
const _tertiaryContainer     = Color(0xFF057241);
const _onTertiaryContainer   = Color(0xFF97F3B6);
const _error                 = Color(0xFFBA1A1A);
const _onError               = Color(0xFFFFFFFF);
const _errorContainer        = Color(0xFFFFDAD6);
const _onErrorContainer      = Color(0xFF93000A);
const _background            = Color(0xFFF7FAF8);
const _surface               = Color(0xFFF7FAF8);
const _onSurface             = Color(0xFF181C1C);
const _onSurfaceVariant      = Color(0xFF3F4945);
const _surfaceContainerLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow   = Color(0xFFF1F4F2);
const _outline               = Color(0xFF6F7975);
const _outlineVariant        = Color(0xFFBEC9C4);
const _inverseSurface        = Color(0xFF2D3130);
const _inverseOnSurface      = Color(0xFFEEF1EF);
const _inversePrimary        = Color(0xFF8AD5BE);
const _surfaceTint           = Color(0xFF186A57);

// Soft 4%-opacity primary-tinted card shadow
const _cardShadow = BoxShadow(
  color: Color(0x0A005645), // primary at ~4% opacity
  blurRadius: 20,
  offset: Offset(0, 4),
);

// ─── Shape radii ─────────────────────────────────────────────────────────────
const _cardRadius   = 20.0;
const _inputRadius  = 12.0;
const _chipRadius   = 100.0;

// ─── Typography helpers ───────────────────────────────────────────────────────
TextStyle _jakarta(double size, FontWeight weight, {double height = 1.0, double? letterSpacing}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight,
        height: height, letterSpacing: letterSpacing);

TextStyle _inter(double size, FontWeight weight, {double height = 1.0}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, height: height);

TextStyle _jbMono(double size, FontWeight weight, {double height = 1.0, double? letterSpacing}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight,
        height: height, letterSpacing: letterSpacing);

// ─── Public card shadow ───────────────────────────────────────────────────────
/// Reusable soft card shadow — import from here so it's always consistent.
const cardShadow = _cardShadow;

// ─── ThemeData builder ────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _primary,
    onPrimary: _onPrimary,
    primaryContainer: _primaryContainer,
    onPrimaryContainer: _onPrimaryContainer,
    secondary: _secondary,
    onSecondary: _onSecondary,
    secondaryContainer: _secondaryContainer,
    onSecondaryContainer: _onSecondaryContainer,
    tertiary: _tertiary,
    onTertiary: _onTertiary,
    tertiaryContainer: _tertiaryContainer,
    onTertiaryContainer: _onTertiaryContainer,
    error: _error,
    onError: _onError,
    errorContainer: _errorContainer,
    onErrorContainer: _onErrorContainer,
    surface: _surface,
    onSurface: _onSurface,
    onSurfaceVariant: _onSurfaceVariant,
    outline: _outline,
    outlineVariant: _outlineVariant,
    inverseSurface: _inverseSurface,
    onInverseSurface: _inverseOnSurface,
    inversePrimary: _inversePrimary,
    surfaceTint: _surfaceTint,
  );

  final textTheme = TextTheme(
    // Display
    displayLarge: _jakarta(48, FontWeight.w700, height: 56/48, letterSpacing: -0.02 * 48),
    // Headlines
    headlineLarge:  _jakarta(32, FontWeight.w600, height: 40/32, letterSpacing: -0.01 * 32),
    headlineMedium: _jakarta(24, FontWeight.w600, height: 32/24),
    headlineSmall:  _jakarta(28, FontWeight.w600, height: 36/28),
    // Title (used for AppBar titles etc)
    titleLarge:  _jakarta(22, FontWeight.w600),
    titleMedium: _jakarta(16, FontWeight.w600),
    titleSmall:  _jakarta(14, FontWeight.w600),
    // Body
    bodyLarge:  _inter(18, FontWeight.w400, height: 28/18),
    bodyMedium: _inter(16, FontWeight.w400, height: 24/16),
    bodySmall:  _inter(14, FontWeight.w400, height: 20/14),
    // Label (JetBrains Mono for data/codes)
    labelLarge:  _jbMono(14, FontWeight.w500, height: 20/14, letterSpacing: 0.02 * 14),
    labelMedium: _jbMono(12, FontWeight.w500, height: 16/12, letterSpacing: 0.05 * 12),
    labelSmall:  _jbMono(11, FontWeight.w500, height: 16/11),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _background,
    textTheme: textTheme,

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: _background,
      foregroundColor: _onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _jakarta(20, FontWeight.w600, height: 1.2),
      iconTheme: const IconThemeData(color: _onSurface, size: 24),
    ),

    // ── Bottom Navigation ────────────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _surfaceContainerLowest,
      selectedItemColor: _primary,
      unselectedItemColor: _outline,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    // ── Cards ────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: _surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
    ),

    // ── Input decoration ─────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: _outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: _outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: _error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: _error, width: 1.5),
      ),
      labelStyle: _inter(16, FontWeight.w400).copyWith(color: _onSurfaceVariant),
      hintStyle: _inter(16, FontWeight.w400).copyWith(color: _outlineVariant),
    ),

    // ── Chips ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceContainerLow,
      selectedColor: _secondaryContainer,
      labelStyle: _inter(14, FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_chipRadius),
      ),
      side: const BorderSide(color: _outlineVariant, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // ── Divider ───────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: _outlineVariant,
      thickness: 1,
      space: 0,
    ),

    // ── Extensions ────────────────────────────────────────────────────────────
    extensions: const <ThemeExtension<dynamic>>[
      PlastiScanColors.light,
    ],
  );
}
