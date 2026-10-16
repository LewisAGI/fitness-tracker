import 'package:flutter/material.dart';

class AppColors {
  static const canvas = Color(0xFFFFFFFF);
  static const accent = Color(0xFFF15A22);
  static const accentPressed = Color(0xFFD14A18);
  static const accentSoft = Color(0xFFFFE8DE);
  static const ink = Color(0xFF1C1917);
  static const muted = Color(0xFF78716C);
  static const hairline = Color(0xFFE7E5E4);
}

ThemeData buildTheme() {
  const accent = AppColors.accent;
  final scheme = ColorScheme.light(
    primary: accent,
    onPrimary: Colors.white,
    secondary: accent,
    onSecondary: Colors.white,
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    outline: AppColors.hairline,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.canvas,
    splashColor: AppColors.accentSoft,
    dividerColor: AppColors.hairline,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontFamily: 'Roboto',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: AppColors.accent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: AppColors.hairline,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

BoxDecoration cardBox() {
  return BoxDecoration(
    color: AppColors.canvas,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.hairline),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0A1C1917),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
  );
}
