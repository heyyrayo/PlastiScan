import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

Future<void> goBackOrHome(BuildContext context) async {
  if (context.canPop()) {
    context.pop();
    return;
  }

  if (context.mounted) {
    context.go('/');
  }
}

Future<void> handleSystemBack(BuildContext context, String location) async {
  if (location != '/') {
    context.go('/');
    return;
  }

  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Exit PlastiScan?'),
      content: const Text('Are you sure you want to quit the application?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Exit'),
        ),
      ],
    ),
  );

  if (shouldExit == true) {
    await SystemNavigator.pop();
  }
}

class AppBackHandler extends StatelessWidget {
  const AppBackHandler({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          handleSystemBack(context, location);
        }
      },
      child: child,
    );
  }
}