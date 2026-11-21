import 'package:flutter/material.dart';

import '../constants/lunaria_colors.dart';

abstract final class LunariaTheme {
  static ThemeData get light {
    final textTheme = ThemeData.light().textTheme.copyWith(
      displaySmall: const TextStyle(
        color: LunariaColors.plumDark,
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: const TextStyle(
        color: LunariaColors.plumDark,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: const TextStyle(
        color: LunariaColors.plumDark,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: LunariaColors.plum,
        brightness: Brightness.light,
        primary: LunariaColors.plum,
        onPrimary: Colors.white,
        surface: LunariaColors.cream,
        onSurface: LunariaColors.ink,
        secondary: LunariaColors.rose,
        error: LunariaColors.danger,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: LunariaColors.cream,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: LunariaColors.mauve.withValues(alpha: .16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: LunariaColors.mauve.withValues(alpha: .35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: LunariaColors.mauve.withValues(alpha: .28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LunariaColors.plum, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: LunariaColors.blush,
      ),
    );
  }

  static ThemeData get dark {
    return light.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF241D23),
      colorScheme: const ColorScheme.dark(
        primary: LunariaColors.blush,
        onPrimary: LunariaColors.plumDark,
        surface: Color(0xFF241D23),
        onSurface: Color(0xFFFCECF3),
      ),
    );
  }
}
