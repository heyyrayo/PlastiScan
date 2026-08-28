import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

bool _exitDialogVisible = false;

bool isPrimaryDestination(String location) {
  return location == '/' ||
      location == '/history' ||
      location == '/manual-entry' ||
      location == '/profile';
}

Future<void> goBackOrHome(BuildContext context) async {
  final location = GoRouterState.of(context).uri.path;

  if (!isPrimaryDestination(location) && context.canPop()) {
    context.pop();
    return;
  }

  if (location != '/') {
    context.go('/');
  }
}

Future<void> handleSystemBack(BuildContext context, String location) async {
  if (!isPrimaryDestination(location) && context.canPop()) {
    context.pop();
    return;
  }

  if (location != '/') {
    context.go('/');
    return;
  }

  if (_exitDialogVisible) return;
  _exitDialogVisible = true;

  final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Exit PlastiScan?'),
          content: const Text(
            'Are you sure you want to close PlastiScan? Your saved scans and account data will remain safely stored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('QUIT'),
            ),
          ],
        ),
      ) ??
      false;
  _exitDialogVisible = false;

  if (shouldExit == true) {
    await SystemNavigator.pop();
  }
}

class AppBackHandler extends StatelessWidget {
  const AppBackHandler({
    required this.child,
    required this.location,
    super.key,
  });

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !isPrimaryDestination(location),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          handleSystemBack(context, location);
        }
      },
      child: child,
    );
  }
}
