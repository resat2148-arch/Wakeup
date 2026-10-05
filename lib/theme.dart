import 'package:flutter/material.dart';

const sunriseOrange = Color(0xFFFF8A3D);
const sunriseGold = Color(0xFFFFC857);
const nightIndigo = Color(0xFF1B1B3A);
const dawnPurple = Color(0xFF5B3E8E);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: sunriseOrange,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    cardTheme: const CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
  );
}

/// Uyandırma ekranında gece → gündoğumu geçişi.
LinearGradient dawnGradient(double t) {
  final top = Color.lerp(nightIndigo, const Color(0xFF3A6EA5), t)!;
  final mid = Color.lerp(dawnPurple, const Color(0xFFFF9E6D), t)!;
  final bottom = Color.lerp(sunriseOrange, sunriseGold, t)!;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, mid, bottom],
    stops: const [0, 0.6, 1],
  );
}
