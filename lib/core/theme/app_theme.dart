import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_theme_palette.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      palette: AppThemePalette.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandPrimary,
        secondary: AppColors.secondaryBlue,
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFEF4444),
        onPrimary: AppColors.textInverse,
        onSecondary: AppColors.textInverse,
        onSurface: AppColors.textPrimary,
        outline: Color(0xFFE8E7F0),
      ),
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      palette: AppThemePalette.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimaryLight,
        secondary: AppColors.secondaryBlue,
        surface: Color(0xFF1B1F30),
        error: Color(0xFFFF7A7A),
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textInverse,
        onSurface: Color(0xFFF5F7FF),
        outline: Color(0xFF353A50),
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppThemePalette palette,
    required ColorScheme colorScheme,
  }) {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      brightness: brightness,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: palette.pageBackground,
      colorScheme: colorScheme,
      cardColor: palette.surfacePrimary,
      canvasColor: palette.surfacePrimary,
      textTheme: baseTextTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.pageBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: palette.borderSoft,
      focusColor: AppColors.borderFocus,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: palette.textPlaceholder,
        ),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: AppColors.brandPrimary.withValues(alpha: 0.28),
        selectionHandleColor: colorScheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            brightness == Brightness.dark ? palette.surfaceSecondary : colorScheme.onSurface,
        contentTextStyle: TextStyle(
          color:
              brightness == Brightness.dark ? colorScheme.onSurface : AppColors.textInverse,
        ),
      ),
      useMaterial3: true,
    );
  }
}
