import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Tokens en Keychain/Keystore (nunca en SharedPreferences). Copia en memoria para no leer
/// almacenamiento seguro en cada request.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  final FlutterSecureStorage _storage;
  AuthTokens? _cache;
  static const _kAccess = 'kinti.access';
  static const _kRefresh = 'kinti.refresh';
  static const _kUser = 'kinti.userId';

  Future<AuthTokens?> read() async {
    if (_cache != null) return _cache;
    final a = await _storage.read(key: _kAccess);
    final r = await _storage.read(key: _kRefresh);
    if (a == null || r == null) return null;
    return _cache = AuthTokens(accessToken: a, refreshToken: r);
  }

  Future<void> save(AuthTokens t, {String? userId}) async {
    _cache = t;
    await _storage.write(key: _kAccess, value: t.accessToken);
    await _storage.write(key: _kRefresh, value: t.refreshToken);
    if (userId != null) await _storage.write(key: _kUser, value: userId);
  }

  Future<String?> userId() => _storage.read(key: _kUser);

  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
