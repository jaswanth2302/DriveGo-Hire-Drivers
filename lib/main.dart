import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/geo/config/geo_config.dart';
import 'data/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize geo config from .env (also loads dotenv)
  try {
    await GeoConfig.initialize();
  } catch (e) {
    debugPrint('[Main] GeoConfig init failed: $e');
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[Main] Supabase init failed: $e');
  }

  runApp(
    const ProviderScope(
      child: DrivoApp(),
    ),
  );
}

class DrivoApp extends ConsumerWidget {
  const DrivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
