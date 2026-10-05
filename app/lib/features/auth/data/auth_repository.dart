import 'package:dio/dio.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/interceptors.dart';
import '../../../core/storage/token_store.dart';

class UserProfile {
  const UserProfile({required this.id, required this.firstName, required this.lastName, required this.email});
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    email: j['email'] as String,
  );
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  Map<String, dynamic> toJson() => {'id': id, 'firstName': firstName, 'lastName': lastName, 'email': email};
}

class RegistrationData {
  const RegistrationData({
    required this.cedula,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.birthDate,
    required this.password,
    required this.acceptTerms,
  });
  final String cedula, firstName, lastName, email, phone, password;
  final DateTime birthDate;
  final bool acceptTerms;

  Map<String, dynamic> toJson() => {
    'cedula': cedula,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'birthDate':
        '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
    'password': password,
    'acceptTerms': acceptTerms,
  };
}

class RegistrationTicket {
  const RegistrationTicket({required this.userId, required this.maskedPhone, this.devOtp});
  final String userId;
  final String maskedPhone;

  /// Solo en entornos de demo (sin proveedor SMS). En producción el BFF no lo envía.
  final String? devOtp;
}

class AuthRepository {
  AuthRepository({required this.api, required this.tokens, required this.cache});
  final ApiClient api;
  final TokenStore tokens;
  final CacheStore cache;

  static final _public = Options(extra: {AuthInterceptor.skipAuth: true});

  Future<UserProfile> login(String username, String password) async {
    final json = await api.post<Json>(
      '/v1/auth/login',
      body: {'username': username.trim(), 'password': password},
      options: _public,
    );
    return _persistSession(json);
  }

  Future<RegistrationTicket> register(RegistrationData data) async {
    final j = await api.post<Json>('/v1/auth/register', body: data.toJson(), options: _public);
    return RegistrationTicket(
      userId: j['userId'] as String,
      maskedPhone: j['maskedPhone'] as String,
      devOtp: j['devOtp'] as String?,
    );
  }

  Future<String?> resendOtp(String userId) async {
    final j = await api.post<Json>('/v1/auth/otp/resend', body: {'userId': userId}, options: _public);
    return j['devOtp'] as String?;
  }

  Future<UserProfile> verifyOtp(String userId, String code) async {
    final json = await api.post<Json>('/v1/auth/otp/verify', body: {'userId': userId, 'code': code}, options: _public);
    return _persistSession(json);
  }

  /// Restaura la sesión al abrir la app. Funciona offline usando el perfil cacheado.
  Future<UserProfile?> restore() async {
    final t = await tokens.read();
    if (t == null) return null;
    final uid = await tokens.userId();
    cache.setNamespace(uid);
    final cached = cache.read('profile');
    if (cached?.data is Map) return UserProfile.fromJson(Map<String, dynamic>.from(cached!.data! as Map));
    try {
      final me = await api.get<Json>('/v1/me');
      await cache.write('profile', UserProfile.fromJson(me).toJson());
      return UserProfile.fromJson(me);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final t = await tokens.read();
    if (t != null) {
      try {
        await api.post<dynamic>('/v1/auth/logout', body: {'refreshToken': t.refreshToken}, options: _public);
      } catch (_) {
        /* mejor esfuerzo: la sesión local se elimina igual */
      }
    }
    await tokens.clear();
    await cache.clearAll();
    cache.setNamespace(null);
  }

  Future<UserProfile> _persistSession(Json json) async {
    final user = UserProfile.fromJson(Map<String, dynamic>.from(json['user'] as Map));
    await tokens.save(
      AuthTokens(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String),
      userId: user.id,
    );
    cache.setNamespace(user.id);
    await cache.write('profile', user.toJson());
    return user;
  }
}
