import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/cache/cache_store.dart';
import 'tokens.dart';

class ThemeState extends Equatable {
  const ThemeState({this.seed = KColors.brandDefault, this.mode = ThemeMode.system, this.segment = 'clasico'});
  final Color seed;
  final ThemeMode mode;
  final String segment;
  @override
  List<Object?> get props => [seed, mode, segment];
}

/// Tema dirigido por servidor (segmento) + preferencia del usuario (claro/oscuro).
/// Se persiste para que el arranque en frío ya use el tema correcto, incluso offline.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._cache) : super(const ThemeState()) {
    final c = _cache.read('theme');
    if (c?.data is Map) _applyJson(Map<String, dynamic>.from(c!.data! as Map));
  }
  final CacheStore _cache;

  void applyServerTheme(Map<String, dynamic> theme) {
    _applyJson(theme);
    _cache.write('theme', theme);
  }

  void setMode(ThemeMode mode) => emit(ThemeState(seed: state.seed, mode: mode, segment: state.segment));

  void reset() => emit(const ThemeState());

  void _applyJson(Map<String, dynamic> t) {
    emit(
      ThemeState(
        seed: hexColor(t['seedColor'] as String?),
        mode: switch (t['mode']) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        segment: (t['segment'] as String?) ?? 'clasico',
      ),
    );
  }
}
