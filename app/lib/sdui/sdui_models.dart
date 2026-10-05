import 'package:equatable/equatable.dart';

/// Versión máxima del esquema SDUI que esta build entiende.
const kSupportedSduiSchema = 1;

class SduiSection extends Equatable {
  const SduiSection({required this.id, required this.type, this.data = const {}});
  final String id;
  final String type;
  /// Propiedades del componente (equivalente a `props` en el JSON).
  final Map<String, dynamic> data;

  String? str(String k) => data[k] is String ? data[k] as String : null;
  bool flag(String k, {bool fallback = false}) => data[k] is bool ? data[k] as bool : fallback;
  Map<String, dynamic>? map(String k) => data[k] is Map ? Map<String, dynamic>.from(data[k] as Map) : null;
  List<Map<String, dynamic>> list(String k) => data[k] is List
      ? (data[k] as List).whereType<Map<dynamic, dynamic>>().map(Map<String, dynamic>.from).toList()
      : const [];

  @override
  List<Object?> get props => [id, type, data];
}

class SduiScreen extends Equatable {
  const SduiScreen({
    required this.schemaVersion,
    required this.sections,
    this.theme = const {},
    this.ttlSeconds = 300,
    this.reasons = const [],
    this.segment,
    this.isFallback = false,
  });

  final int schemaVersion;
  final List<SduiSection> sections;
  final Map<String, dynamic> theme;
  final int ttlSeconds;
  final List<String> reasons;
  final String? segment;
  final bool isFallback;

  /// Parseo tolerante: secciones mal formadas se descartan individualmente en lugar de
  /// invalidar toda la pantalla. Un esquema mayor al soportado se rechaza (→ fallback).
  factory SduiScreen.fromJson(Object? json, {bool isFallback = false}) {
    if (json is! Map) throw const FormatException('SDUI: payload inválido');
    final version = json['schemaVersion'];
    if (version is! int || version > kSupportedSduiSchema) {
      throw FormatException('SDUI: esquema $version no soportado');
    }
    final sections = <SduiSection>[];
    for (final raw in (json['sections'] as List?) ?? const []) {
      if (raw is Map && raw['type'] is String && raw['id'] is String) {
        sections.add(SduiSection(
          id: raw['id'] as String,
          type: raw['type'] as String,
          data: raw['props'] is Map ? Map<String, dynamic>.from(raw['props'] as Map) : const {},
        ));
      }
    }
    final meta = json['meta'] is Map ? json['meta'] as Map : const {};
    return SduiScreen(
      schemaVersion: version,
      sections: sections,
      theme: json['theme'] is Map ? Map<String, dynamic>.from(json['theme'] as Map) : const {},
      ttlSeconds: (json['ttlSeconds'] as int?) ?? 300,
      reasons: ((meta['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
      segment: meta['segment'] as String?,
      isFallback: isFallback,
    );
  }

  @override
  List<Object?> get props => [schemaVersion, sections, theme, ttlSeconds, reasons, segment, isFallback];
}
