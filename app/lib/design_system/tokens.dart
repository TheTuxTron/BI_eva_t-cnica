import 'package:flutter/material.dart';

/// Tokens base. El color de marca por segmento llega del servidor (SDUI theme);
/// estos son los neutrales y semánticos que no cambian.
abstract final class KColors {
  static const ink = Color(0xFF24303D);
  static const inkMuted = Color(0xFF5E6B78);
  static const paper = Color(0xFFF6F7F9);
  static const line = Color(0xFFDDE3EA);
  static const positive = Color(0xFF2F8F6B);
  static const negative = Color(0xFFC8443A);
  static const warning = Color(0xFFB7791F);
  static const brandDefault = Color(0xFFE46F0A);
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
