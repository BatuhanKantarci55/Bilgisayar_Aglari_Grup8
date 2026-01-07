import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/pages/home_page.dart'; // Import the new HomePage file
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_application_1/ui/common/error_watcher.dart'; // Import ErrorWatcher

void main() {
  app_theme.initThemeNotifiers(); // Initialize theme notifiers
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget { // Changed to ConsumerWidget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Added WidgetRef ref
    // Initialize ErrorWatcher early in the widget tree by watching its provider.
    // This will set up global error handlers safely.
    // ref.watch(errorWatcherProvider);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: app_theme.themeModeNotifier, // Listen to themeModeNotifier
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Flutter Desktop Layout',
          themeMode: themeMode, // Set themeMode
          theme: ThemeData(
            colorScheme: app_theme.lightColorScheme, // Light theme colors
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: app_theme.darkColorScheme, // Dark theme colors
            useMaterial3: true,
          ),
          home: const HomePage(), // HomePage is now a ConsumerStatefulWidget, so it's a valid Widget
        );
      },
    );
  }
}
