import 'package:flutter/material.dart';

/// Paleta basada en la identidad de Banco Internacional (naranja #FF8100, café #614E4B,
/// durazno #FFDEBC). Contrastes verificados contra WCAG 2.1 AA (ver docs/design-system.md).
abstract final class KColors {
  // Marca
  static const brandOrange = Color(0xFFFF8100); // superficies de marca, con texto oscuro (6,1:1)
  static const brandOrangeLight = Color(0xFFFFA347);
  static const brandOrangeText = Color(0xFFB85A00); // naranja para texto/íconos sobre blanco (4,7:1)
  static const brandCafe = Color(0xFF614E4B); // segundo color de marca, texto blanco (7,8:1)
  static const brandCafeDeep = Color(0xFF3F322F);
  static const brandPeach = Color(0xFFFFDEBC);
  static const onPeach = Color(0xFF4A2800);

  // Neutrales cálidos
  static const ink = Color(0xFF2B2422);
  static const inkMuted = Color(0xFF6B5D59);
  static const paper = Color(0xFFF7F5F3);
  static const line = Color(0xFFE7DFDA);
  static const darkBg = Color(0xFF171312);
  static const darkSurface = Color(0xFF221C1A);
  static const darkLine = Color(0xFF3A302D);

  // Semánticos (todos ≥ 4,5:1 sobre blanco)
  static const positive = Color(0xFF23785A);
  static const negative = Color(0xFFC8443A);
  static const warning = Color(0xFF8A5A12);

  static const brandDefault = brandOrange;
}

abstract final class KSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Jerarquía de radios: el saldo (elemento protagonista) es el más redondeado.
abstract final class KRadius {
  static const hero = 24.0;
  static const card = 16.0;
  static const chip = 10.0;
}

abstract final class KMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 280);
}

Color hexColor(String? hex, {Color fallback = KColors.brandDefault}) {
  if (hex == null) return fallback;
  final h = hex.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Colores de marca derivados del segmento, accesibles desde cualquier widget:
/// `Theme.of(context).extension<KBrand>()!` o `KBrand.of(context)`.
@immutable
class KBrand extends ThemeExtension<KBrand> {
  const KBrand({
    required this.action,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroAccent,
  });

  /// Color para textos, enlaces e íconos interactivos (siempre con contraste AA).
  final Color action;

  /// Fondo de la tarjeta de saldo (elemento protagonista).
  final Gradient hero;
  final Color onHero;
  final Color onHeroMuted;

  /// Detalle de acento sobre el hero (línea, chip).
  final Color heroAccent;

  static KBrand of(BuildContext context) =>
      Theme.of(context).extension<KBrand>() ?? KBrand.forSegment('clasico', Brightness.light);

  /// Cada segmento tiene su propia expresión, siempre dentro de la marca:
  /// joven = naranja vibrante en degradé; clásico = naranja sólido; premium = café profundo con acento naranja.
  factory KBrand.forSegment(String segment, Brightness brightness) {
    final light = brightness == Brightness.light;
    switch (segment) {
      case 'premium':
        return KBrand(
          action: light ? KColors.brandCafe : KColors.brandPeach,
          hero: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KColors.brandCafe, KColors.brandCafeDeep],
          ),
          onHero: Colors.white,
          onHeroMuted: KColors.brandPeach,
          heroAccent: KColors.brandOrange,
        );
      case 'joven':
        return KBrand(
          action: light ? KColors.brandOrangeText : KColors.brandOrangeLight,
          hero: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KColors.brandOrange, KColors.brandOrangeLight],
          ),
          onHero: KColors.ink,
          onHeroMuted: KColors.brandCafeDeep,
          heroAccent: KColors.ink,
        );
      default:
        return KBrand(
          action: light ? KColors.brandOrangeText : KColors.brandOrangeLight,
          hero: const LinearGradient(colors: [KColors.brandOrange, KColors.brandOrange]),
          onHero: KColors.ink,
          onHeroMuted: KColors.brandCafeDeep,
          heroAccent: KColors.ink,
        );
    }
  }

  @override
  KBrand copyWith({Color? action, Gradient? hero, Color? onHero, Color? onHeroMuted, Color? heroAccent}) => KBrand(
    action: action ?? this.action,
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
    onHeroMuted: onHeroMuted ?? this.onHeroMuted,
    heroAccent: heroAccent ?? this.heroAccent,
  );

  @override
  KBrand lerp(ThemeExtension<KBrand>? other, double t) {
    if (other is! KBrand) return this;
    return KBrand(
      action: Color.lerp(action, other.action, t)!,
      hero: Gradient.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      onHeroMuted: Color.lerp(onHeroMuted, other.onHeroMuted, t)!,
      heroAccent: Color.lerp(heroAccent, other.heroAccent, t)!,
    );
  }
}
