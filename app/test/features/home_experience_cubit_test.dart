import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/core/cache/cache_store.dart';
import 'package:kinti/core/cache/resource.dart';
import 'package:kinti/core/network/failures.dart';
import 'package:kinti/design_system/theme_cubit.dart';
import 'package:kinti/features/personalization/data/experience_repository.dart';
import 'package:kinti/features/personalization/presentation/home_experience_cubit.dart';
import 'package:kinti/sdui/sdui_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

class MockExperience extends Mock implements ExperienceRepository {}

void main() {
  late MockExperience repo;
  late ThemeCubit theme;
  late FakeTelemetry telemetry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MockExperience();
    theme = ThemeCubit(CacheStore(await SharedPreferences.getInstance()));
    telemetry = FakeTelemetry();
  });

  test('aplica el tema del segmento que decide el servidor', () async {
    final screen = SduiScreen.fromJson({
      'schemaVersion': 1,
      'theme': {'segment': 'premium', 'seedColor': '#1F3A5F', 'mode': 'dark'},
      'sections': [],
    });
    when(
      () => repo.watchHome(),
    ).thenAnswer((_) => Stream<Resource<SduiScreen>>.fromIterable([const Resource.loading(), Resource(data: screen)]));
    final c = HomeExperienceCubit(repo, theme, telemetry);
    await c.load();
    expect(theme.state.segment, 'premium');
    expect(c.state.data, screen);
  });

  test('sin servicio y sin caché: usa la experiencia embebida (nunca pantalla vacía)', () async {
    when(() => repo.watchHome()).thenAnswer(
      (_) => Stream<Resource<SduiScreen>>.fromIterable([
        const Resource.loading(),
        const Resource(error: ServiceUnavailableFailure('caído', code: 'X')),
      ]),
    );
    final c = HomeExperienceCubit(repo, theme, telemetry);
    await c.load();
    expect(c.state.data!.isFallback, isTrue);
    expect(c.state.data!.sections.map((s) => s.type), contains('account_summary'));
    expect(telemetry.events, contains('home_fallback_rendered'));
  });
}
