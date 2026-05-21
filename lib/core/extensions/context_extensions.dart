import 'package:flutter/material.dart';

import '../theme/app_theme_palette.dart';

extension AppContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  AppThemePalette get palette =>
      theme.extension<AppThemePalette>() ?? AppThemePalette.light;
}
