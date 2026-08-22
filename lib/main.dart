import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Ensures Flutter is fully initialized before
  // loading environment variables and Supabase.
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Start the application
  runApp(
    const ProviderScope(
      child: PlastiScanApp(),
    ),
  );
}

class PlastiScanApp extends StatelessWidget {
  const PlastiScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PlastiScan',
      debugShowCheckedModeBanner: false,

      // Existing PlastiScan design system
      theme: buildAppTheme(),

      // Existing application routing
      routerConfig: appRouter,
    );
  }
}
