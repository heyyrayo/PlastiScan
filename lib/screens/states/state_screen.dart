import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/app_navigation.dart';
import '../../widgets/buttons/app_buttons.dart';

/// Shared parameterized state screen for all edge/empty states:
/// offline, no-internet, analysis-failed, no-history, unknown-product.
class StateScreen extends StatelessWidget {
  const StateScreen({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.illustrationAsset,
  });

  final IconData icon;
  final String headline;
  final String body;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Color? iconColor;
  /// Optional asset path for a hero illustration (e.g. 'assets/illustrations/state_illustration.png').
  /// When provided, replaces the plain icon circle.
  final String? illustrationAsset;

  // ─── Named constructors for each state ────────────────────────────────────

  factory StateScreen.offline(BuildContext context) => StateScreen(
        icon: Icons.wifi_off_rounded,
        headline: 'You are Offline',
        body: 'Check your Wi-Fi or mobile data connection and try again.',
        primaryActionLabel: 'Retry',
        onPrimaryAction: () => context.go('/'),
        secondaryActionLabel: 'Use Offline Mode',
        onSecondaryAction: () => context.go('/'),
        iconColor: const Color(0xFF78909C),
        illustrationAsset: 'assets/illustrations/state_illustration.png',
      );

  factory StateScreen.noInternet(BuildContext context) => StateScreen(
        icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
        headline: 'No Internet Connection',
        body: 'PlastiScan needs internet to run AI analysis.\nYou can still browse your saved history.',
        primaryActionLabel: 'Retry',
        onPrimaryAction: () => context.go('/'),
        secondaryActionLabel: 'View History',
        onSecondaryAction: () => context.go('/history'),
        iconColor: const Color(0xFF78909C),
        illustrationAsset: 'assets/illustrations/state_illustration.png',
      );

  factory StateScreen.analysisFailed(BuildContext context) => StateScreen(
        icon: Icons.error_outline_rounded,
        headline: 'Analysis Failed',
        body: 'We could not process this item. The image may be unclear,\nor the plastic type is not in our database.',
        primaryActionLabel: 'Try Again',
        onPrimaryAction: () => context.go('/scan'),
        secondaryActionLabel: 'Enter Manually',
        onSecondaryAction: () => context.go('/manual-entry'),
        iconColor: const Color(0xFFBA1A1A),
        illustrationAsset: 'assets/illustrations/state_illustration.png',
      );

  factory StateScreen.noHistory(BuildContext context) => StateScreen(
        icon: Icons.history_rounded,
        headline: 'No Scans Yet',
        body: 'Your scan history will appear here.\nStart by scanning a plastic item.',
        primaryActionLabel: 'Scan Now',
        onPrimaryAction: () => context.go('/scan'),
        iconColor: const Color(0xFF3C6657),
        illustrationAsset: 'assets/illustrations/state_illustration.png',
      );

  factory StateScreen.unknownProduct(BuildContext context) => StateScreen(
        icon: Icons.help_outline_rounded,
        headline: 'Product Not Recognised',
        body: 'We could not identify this product from the scan.\nTry entering the plastic code manually.',
        primaryActionLabel: 'Manual Entry',
        onPrimaryAction: () => context.go('/manual-entry'),
        secondaryActionLabel: 'Scan Again',
        onSecondaryAction: () => context.go('/scan'),
        iconColor: const Color(0xFFF9A825),
        illustrationAsset: 'assets/illustrations/state_illustration.png',
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final iconClr = iconColor ?? cs.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOrHome(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustrationAsset != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    illustrationAsset!,
                    width: 240,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: iconClr.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: iconClr),
                ),
              const SizedBox(height: 32),

              Text(
                headline,
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: primaryActionLabel,
                  onPressed: onPrimaryAction,
                ),
              ),

              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: secondaryActionLabel!,
                    onPressed: onSecondaryAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
