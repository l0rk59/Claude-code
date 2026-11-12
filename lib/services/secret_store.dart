import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where secrets (API keys, tokens) are kept: the phone's keystore, not the
/// app's ordinary settings file.
abstract class SecretStore {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore (iOS Keychain, the browser's storage on the web).
class KeystoreSecretStore implements SecretStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps secrets in memory only: for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values;
  MemorySecretStore([Map<String, String>? initial]) : values = {...?initial};

  @override
  Future<Map<String, String>> readAll() async => {...values};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
