import 'package:flutter/material.dart';

import 'tokens.dart';

class KTheme {
  static ThemeData build({required Color seed, required Brightness brightness, String segment = 'clasico'}) {
    final light = brightness == Brightness.light;
    final brand = KBrand.forSegment(segment, brightness);
    final generated = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    // Texto sobre el color de marca según su luminancia: oscuro sobre naranja, blanco sobre café.
    final onSeed = ThemeData.estimateBrightnessForColor(seed) == Brightness.dark ? Colors.white : KColors.ink;
    final scheme = light
        ? generated.copyWith(
            primary: seed,
            onPrimary: onSeed,
            primaryContainer: KColors.brandPeach,
            onPrimaryContainer: KColors.onPeach,
            secondary: KColors.brandCafe,
            onSecondary: Colors.white,
            tertiaryContainer: KColors.brandPeach,
            onTertiaryContainer: KColors.onPeach,
            surface: Colors.white,
            onSurface: KColors.ink,
            onSurfaceVariant: KColors.inkMuted,
            outline: KColors.inkMuted,
            outlineVariant: KColors.line,
            error: KColors.negative,
          )
        : generated.copyWith(
            primary: segment == 'premium' ? KColors.brandPeach : KColors.brandOrangeLight,
            onPrimary: KColors.ink,
            secondary: KColors.brandPeach,
            surface: KColors.darkSurface,
            outlineVariant: KColors.darkLine,
          );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return base.copyWith(
      extensions: [brand],
      scaffoldBackgroundColor: light ? KColors.paper : KColors.darkBg,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: brand.action,
          side: BorderSide(color: brand.action),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: brand.action)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: light ? KColors.brandOrange : KColors.brandOrangeLight),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: light ? Colors.white : KColors.darkSurface,
        indicatorColor: light ? KColors.brandPeach : KColors.brandCafe,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
