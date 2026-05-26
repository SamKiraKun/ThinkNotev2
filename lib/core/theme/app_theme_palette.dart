import 'package:flutter/material.dart';

@immutable
class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.pageBackground,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceAccent,
    required this.glassSurface,
    required this.borderPrimary,
    required this.borderSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textPlaceholder,
  });

  final Color pageBackground;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceAccent;
  final Color glassSurface;
  final Color borderPrimary;
  final Color borderSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textPlaceholder;

  static const AppThemePalette light = AppThemePalette(
    pageBackground: Color(0xFFF7F6FB),
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFFBFAFF),
    surfaceAccent: Color(0xFFF1ECFF),
    glassSurface: Color(0xE6FFFFFF),
    borderPrimary: Color(0xFFE8E7F0),
    borderSoft: Color(0xFFF0EFF6),
    textPrimary: Color(0xFF101126),
    textSecondary: Color(0xFF5D6077),
    textTertiary: Color(0xFF7C7F96),
    textPlaceholder: Color(0xFFA2A5B8),
  );

  static const AppThemePalette dark = AppThemePalette(
    pageBackground: Color(0xFF0F1320),
    surfacePrimary: Color(0xFF171B28),
    surfaceSecondary: Color(0xFF1F2535),
    surfaceAccent: Color(0xFF262E43),
    glassSurface: Color(0xE6171C2A),
    borderPrimary: Color(0xFF313950),
    borderSoft: Color(0xFF232A3C),
    textPrimary: Color(0xFFF7F8FC),
    textSecondary: Color(0xFFC8CFDD),
    textTertiary: Color(0xFF99A2B8),
    textPlaceholder: Color(0xFF7A849C),
  );

  @override
  AppThemePalette copyWith({
    Color? pageBackground,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceAccent,
    Color? glassSurface,
    Color? borderPrimary,
    Color? borderSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textPlaceholder,
  }) {
    return AppThemePalette(
      pageBackground: pageBackground ?? this.pageBackground,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceAccent: surfaceAccent ?? this.surfaceAccent,
      glassSurface: glassSurface ?? this.glassSurface,
      borderPrimary: borderPrimary ?? this.borderPrimary,
      borderSoft: borderSoft ?? this.borderSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) {
      return this;
    }

    return AppThemePalette(
      pageBackground:
          Color.lerp(pageBackground, other.pageBackground, t) ?? pageBackground,
      surfacePrimary:
          Color.lerp(surfacePrimary, other.surfacePrimary, t) ?? surfacePrimary,
      surfaceSecondary: Color.lerp(
            surfaceSecondary,
            other.surfaceSecondary,
            t,
          ) ??
          surfaceSecondary,
      surfaceAccent:
          Color.lerp(surfaceAccent, other.surfaceAccent, t) ?? surfaceAccent,
      glassSurface:
          Color.lerp(glassSurface, other.glassSurface, t) ?? glassSurface,
      borderPrimary:
          Color.lerp(borderPrimary, other.borderPrimary, t) ?? borderPrimary,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t) ?? borderSoft,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      textPlaceholder:
          Color.lerp(textPlaceholder, other.textPlaceholder, t) ??
              textPlaceholder,
    );
  }
}
