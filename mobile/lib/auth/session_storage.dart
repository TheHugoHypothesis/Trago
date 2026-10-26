import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

class SecureSessionStorage implements SessionStorage {
  static const _tokenKey = 'trago.auth.access_token';
  final FlutterSecureStorage _storage;

  const SecureSessionStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  }) : _storage = storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
