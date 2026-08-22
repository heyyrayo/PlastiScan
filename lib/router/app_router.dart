import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/scan_result.dart';

import '../screens/ai_analysis/ai_analysis_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/manual_entry/manual_entry_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/results/results_screen.dart';
import '../screens/scan/scan_screen.dart';
import '../screens/states/state_screen.dart';

import '../widgets/bottom_nav_bar.dart';

import 'auth_router_notifier.dart';

// ─────────────────────────────────────────────────────────────
// Authentication state
// ─────────────────────────────────────────────────────────────

final authRouterNotifier = AuthRouterNotifier();

// ─────────────────────────────────────────────────────────────
// Shell scaffold with bottom navigation
// ─────────────────────────────────────────────────────────────

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  int get _navIndex {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/manual-entry')) return 3;
    if (location.startsWith('/profile')) return 4;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/');

            case 1:
              context.go('/history');

            case 2:
              context.go('/scan');

            case 3:
              context.go('/manual-entry');

            case 4:
              context.go('/profile');

            default:
              context.go('/');
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Router configuration
// ─────────────────────────────────────────────────────────────

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: authRouterNotifier,
  redirect: (context, state) {
    final isLoggedIn = authRouterNotifier.isLoggedIn;

    final location = state.uri.path;

    final isAuthRoute = location == '/login' || location == '/signup';

    // User is NOT logged in
    if (!isLoggedIn) {
      // Already on login/signup.
      // Let them stay there.
      if (isAuthRoute) {
        return null;
      }

      // Protect everything else.
      return '/login';
    }

    // User IS logged in.
    // Don't allow logged-in users to remain on auth pages.
    if (isAuthRoute) {
      return '/';
    }

    return null;
  },
  routes: [
    // ─────────────────────────────────────────────────────────
    // Authentication routes
    // No bottom navigation
    // ─────────────────────────────────────────────────────────

    GoRoute(
      path: '/login',
      builder: (context, state) {
        return const LoginScreen();
      },
    ),

    GoRoute(
      path: '/signup',
      builder: (context, state) {
        return const SignupScreen();
      },
    ),

    // ─────────────────────────────────────────────────────────
    // Main application shell
    // ─────────────────────────────────────────────────────────

    ShellRoute(
      builder: (context, state, child) {
        return _ShellScaffold(
          location: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const HomeScreen();
          },
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) {
            return const HistoryScreen();
          },
        ),
        GoRoute(
          path: '/manual-entry',
          builder: (context, state) {
            return const ManualEntryScreen();
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) {
            return const ProfileScreen();
          },
        ),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // Full-screen routes
    // No bottom navigation
    // ─────────────────────────────────────────────────────────

    GoRoute(
      path: '/scan',
      builder: (context, state) {
        return const ScanScreen();
      },
    ),

    GoRoute(
      path: '/ai-analysis',
      builder: (context, state) {
        final result = state.extra as ScanResult?;

        return AiAnalysisScreen(
          pendingResult: result,
        );
      },
    ),

    GoRoute(
      path: '/results',
      builder: (context, state) {
        final result = state.extra as ScanResult?;

        return ResultsScreen(
          result: result,
        );
      },
    ),

    // ─────────────────────────────────────────────────────────
    // State / Error Screens
    // ─────────────────────────────────────────────────────────

    GoRoute(
      path: '/state/offline',
      builder: (context, state) {
        return StateScreen.offline(context);
      },
    ),

    GoRoute(
      path: '/state/no-internet',
      builder: (context, state) {
        return StateScreen.noInternet(context);
      },
    ),

    GoRoute(
      path: '/state/analysis-failed',
      builder: (context, state) {
        return StateScreen.analysisFailed(context);
      },
    ),

    GoRoute(
      path: '/state/no-history',
      builder: (context, state) {
        return StateScreen.noHistory(context);
      },
    ),

    GoRoute(
      path: '/state/unknown-product',
      builder: (context, state) {
        return StateScreen.unknownProduct(context);
      },
    ),
  ],
);
