import 'package:material_ui/material_ui.dart';

class AppTheme {
  static const Color background = Color(0xFF090D16);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF192338);
  static const Color border = Color(0xFF263450);

  static const Color cyan = Color(0xFF00E5FF);
  static const Color green = Color(0xFF00E676);
  static const Color amber = Color(0xFFFFB300);
  static const Color red = Color(0xFFFF3D71);
  static const Color purple = Color(0xFF9C6BFF);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: green,
        error: red,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      sliderTheme: SliderThemeData(
        activeTrackColor: cyan,
        inactiveTrackColor: border,
        thumbColor: cyan,
        overlayColor: cyan.withValues(alpha: 0.18),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1.2),
        ),
      ),
    );
  }

  static const TextStyle monoTelemetry = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );
}
