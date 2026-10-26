import 'package:flutter/material.dart';

/// Identité visuelle de Lango : indigo profond (le monde) et ocre (la terre africaine).
class LangoColors {
  static const indigo = Color(0xFF23305E);
  static const ochre = Color(0xFFD9822B);
  static const sand = Color(0xFFF7F1E8);
  static const warning = Color(0xFFB3261E);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: LangoColors.indigo,
    secondary: LangoColors.ochre,
    brightness: brightness,
  );
  final light = brightness == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? LangoColors.sand : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? LangoColors.sand : scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : scheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
