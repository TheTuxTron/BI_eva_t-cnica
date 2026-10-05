import '../../../core/cache/cache_store.dart';
import '../../../core/cache/resource.dart';
import '../../../core/network/api_client.dart';
import '../../../sdui/sdui_models.dart';

class UserPreferences {
  const UserPreferences({
    this.theme = 'system',
    this.hiddenSections = const [],
    this.notificationsEnabled = true,
    this.balanceVisible = true,
  });
  factory UserPreferences.fromJson(Map<String, dynamic> j) => UserPreferences(
    theme: (j['theme'] as String?) ?? 'system',
    hiddenSections: ((j['hiddenSections'] as List?) ?? const []).map((e) => '$e').toList(),
    notificationsEnabled: (j['notificationsEnabled'] as bool?) ?? true,
    balanceVisible: (j['balanceVisible'] as bool?) ?? true,
  );
  final String theme;
  final List<String> hiddenSections;
  final bool notificationsEnabled;
  final bool balanceVisible;

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'hiddenSections': hiddenSections,
    'notificationsEnabled': notificationsEnabled,
    'balanceVisible': balanceVisible,
  };

  UserPreferences copyWith({
    String? theme,
    List<String>? hiddenSections,
    bool? notificationsEnabled,
    bool? balanceVisible,
  }) => UserPreferences(
    theme: theme ?? this.theme,
    hiddenSections: hiddenSections ?? this.hiddenSections,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    balanceVisible: balanceVisible ?? this.balanceVisible,
  );
}

class ProfileInfo {
  const ProfileInfo({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.segment,
    required this.preferences,
  });
  factory ProfileInfo.fromJson(Object? json) {
    final j = Map<String, dynamic>.from(json! as Map);
    return ProfileInfo(
      firstName: j['firstName'] as String,
      lastName: j['lastName'] as String,
      email: j['email'] as String,
      segment: (j['segment'] as String?) ?? 'clasico',
      preferences: UserPreferences.fromJson(Map<String, dynamic>.from((j['preferences'] as Map?) ?? const {})),
    );
  }
  final String firstName, lastName, email, segment;
  final UserPreferences preferences;
}

class ExperienceRepository {
  ExperienceRepository(this.api, this.cache);
  final ApiClient api;
  final CacheStore cache;

  Stream<Resource<SduiScreen>> watchHome() => staleWhileRevalidate(
    cache: cache,
    key: 'experience:home',
    fetch: () => api.get<Json>('/v1/experience/home'),
    decode: SduiScreen.fromJson,
  );

  Stream<Resource<ProfileInfo>> watchProfile() =>
      staleWhileRevalidate(cache: cache, key: 'me', fetch: () => api.get<Json>('/v1/me'), decode: ProfileInfo.fromJson);

  Future<UserPreferences> updatePreferences(UserPreferences p) async {
    final j = await api.put<Json>('/v1/me/preferences', body: p.toJson());
    return UserPreferences.fromJson(j);
  }

  Future<void> sendEvents(List<Map<String, Object?>> events) =>
      api.post<dynamic>('/v1/me/events', body: {'events': events});
}
