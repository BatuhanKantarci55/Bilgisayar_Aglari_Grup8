// theme.dart - REVISED
import 'package:flutter/material.dart';

// Notifier for the current theme mode (light/dark)
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

// Notifier for the seed color, which can be changed by the user
final ValueNotifier<Color> seedColorNotifier = ValueNotifier(const Color(0xFF007AFF)); // M3 Blue

// Notifier for the current color scheme, which updates based on themeMode and seedColor
final ValueNotifier<ColorScheme> colorSchemeNotifier = ValueNotifier(
  _createColorScheme(seedColorNotifier.value, ThemeMode.light),
);

// Update colorSchemeNotifier when seedColorNotifier or themeModeNotifier changes
void initThemeNotifiers() {
  seedColorNotifier.addListener(() {
    colorSchemeNotifier.value = _createColorScheme(seedColorNotifier.value, themeModeNotifier.value);
  });
  themeModeNotifier.addListener(() {
    colorSchemeNotifier.value = _createColorScheme(seedColorNotifier.value, themeModeNotifier.value);
  });
}

// Helper to create a ColorScheme based on seed color and brightness
ColorScheme _createColorScheme(Color seedColor, ThemeMode themeMode) {
  return ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity, // CRITICAL: More vibrant, less washed out
  );
}

// Getters for light and dark ThemeData
ColorScheme get lightColorScheme => _createColorScheme(seedColorNotifier.value, ThemeMode.light);
ColorScheme get darkColorScheme => _createColorScheme(seedColorNotifier.value, ThemeMode.dark);

// Existing colorScheme getter, now reflecting the current theme
ColorScheme get colorScheme => colorSchemeNotifier.value;

// Use Semantic Roles, NOT Opacity Hacks
Color get graphBackground => colorScheme.surfaceContainerLow; 
Color get cardBackground => colorScheme.surfaceContainer;
Color get infoPanelBackground => colorScheme.surfaceContainerLowest;
Color get sideNavBackground => colorScheme.surface;

// Semantic Text Colors
Color get textPrimary => colorScheme.onSurface;
Color get textSecondary => colorScheme.onSurfaceVariant;

/// Rotates the hue of a given color by a specified delta in degrees.
Color _rotateHue(Color color, double hueDelta) {
  final hsl = HSLColor.fromColor(color);
  final newHue = (hsl.hue + hueDelta) % 360;
  return hsl.withHue(newHue).toColor();
}

// Derived colors for source and target nodes using hue rotation
Color get sourceNodeColor {
  // Rotate primary color by 120 degrees for source
  return _rotateHue(colorScheme.primary, 120.0);
}

Color get targetNodeColor {
  // Rotate primary color by 240 degrees (or -120 degrees) for target
  return _rotateHue(colorScheme.primary, 240.0);
}

Color get pathColor => const Color(0xFF00FF00);