import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cache/resource.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/theme_cubit.dart';
import '../../../sdui/fallback_home.dart';
import '../../../sdui/sdui_models.dart';
import '../data/experience_repository.dart';

/// Experiencia de inicio dirigida por servidor con tres niveles de degradación:
/// 1) fresca del servidor, 2) última versión cacheada, 3) experiencia embebida en la app.
class HomeExperienceCubit extends Cubit<Resource<SduiScreen>> {
  HomeExperienceCubit(this._repo, this._theme, this._telemetry) : super(const Resource.loading());
  final ExperienceRepository _repo;
  final ThemeCubit _theme;
  final Telemetry _telemetry;
  StreamSubscription<Resource<SduiScreen>>? _sub;

  static final SduiScreen fallback = SduiScreen.fromJson(kFallbackHome, isFallback: true);

  Future<void> load() async {
    await _sub?.cancel();
    final done = Completer<void>();
    _sub = _repo.watchHome().listen((r) {
      if (r.data != null && r.error == null && !r.fromCache) _theme.applyServerTheme(r.data!.theme);
      if (r.isFatal) {
        _telemetry.event('home_fallback_rendered', {'error': r.error.runtimeType.toString()});
        emit(Resource(data: fallback, error: r.error));
        return;
      }
      emit(r);
    }, onDone: () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
