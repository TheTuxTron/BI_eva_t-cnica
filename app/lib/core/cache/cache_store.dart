import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  const CacheEntry(this.data, this.storedAt);
  final Object? data;
  final DateTime storedAt;
  Duration get age => DateTime.now().difference(storedAt);
}

/// Caché local persistente (JSON + timestamp), aislada por usuario.
/// Se limpia completa al cerrar sesión para no exponer datos de otro cliente.
/// Riesgo documentado: en producción se cifraría (ver docs/architecture.md, R-04).
class CacheStore {
  CacheStore(this._prefs);
  final SharedPreferences _prefs;
  String _namespace = 'anon';
  static const _prefix = 'kc:';

  void setNamespace(String? userId) => _namespace = userId ?? 'anon';

  String _k(String key) => '$_prefix$_namespace:$key';

  CacheEntry? read(String key) {
    final raw = _prefs.getString(_k(key));
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CacheEntry(m['d'], DateTime.fromMillisecondsSinceEpoch(m['t'] as int));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? data) =>
      _prefs.setString(_k(key), jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'd': data}));

  Future<void> clearAll() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await _prefs.remove(k);
    }
  }
}
