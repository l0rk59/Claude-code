import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import 'secret_store.dart';

class HiveService extends GetxService {
  /// Where [AppConstants.secretKeys] are kept. Null: they stay in the
  /// settings box (the keystore couldn't be opened).
  SecretStore? _secretStore;

  /// The secrets, read once at start so reading a setting stays instant.
  final _secrets = <String, dynamic>{};

  HiveService({SecretStore? secrets}) : _secretStore = secrets;

  late Box _sessionsBox;
  late Box _messagesBox;
  late Box _tasksBox;
  late Box _settingsBox;

  Box get sessionsBox => _sessionsBox;
  Box get messagesBox => _messagesBox;
  Box get tasksBox => _tasksBox;
  Box get settingsBox => _settingsBox;

  Future<HiveService> init() async {
    _sessionsBox = await Hive.openBox(AppConstants.chatSessionsBox);
    _messagesBox = await Hive.openBox(AppConstants.chatMessagesBox);
    _tasksBox = await Hive.openBox(AppConstants.tasksBox);
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    // Preserve current local-server settings and purge obsolete provider data.
    // Any new server_* setting must be added here or it is wiped on launch.
    const currentServerKeys = {
      AppConstants.keyServerApiKey,
      AppConstants.keyServerUseApiKey,
      AppConstants.keyServerAllowNetwork,
    };
    final obsoleteServerKeys = _settingsBox.keys.where((key) =>
        key is String &&
        key.startsWith('server_') &&
        !currentServerKeys.contains(key));
    await _settingsBox.deleteAll(obsoleteServerKeys);
    await _openSecrets();
    return this;
  }

  /// Loads the secrets from the keystore, and moves there any still in the
  /// settings box (saved by an earlier version). If the keystore fails, the
  /// secrets stay where they are: losing a key is worse than keeping it in
  /// the app's private storage.
  Future<void> _openSecrets() async {
    final store = _secretStore ??= KeystoreSecretStore();
    try {
      final stored = await store.readAll();
      for (final key in AppConstants.secretKeys) {
        final text = stored[key];
        if (text != null) _secrets[key] = jsonDecode(text);
      }
      var moved = false;
      for (final key in AppConstants.secretKeys) {
        if (!_settingsBox.containsKey(key)) continue;
        final value = _settingsBox.get(key);
        if (!_secrets.containsKey(key) && value != null) {
          await store.write(key, jsonEncode(value));
          _secrets[key] = value;
        }
        await _settingsBox.delete(key);
        moved = true;
      }
      // Hive only marks deleted entries: rewrite the file so the old copies
      // are really gone from the disk.
      if (moved) await _settingsBox.compact();
    } catch (e) {
      // ignore: avoid_print
      print('[HiveService] Keystore unavailable, secrets stay in settings: $e');
      _secretStore = null;
      _secrets.clear();
    }
  }

  bool _isSecret(String key) =>
      _secretStore != null && AppConstants.secretKeys.contains(key);

  // ─── Settings helpers ───────────────────────────

  T? getSetting<T>(String key, {T? defaultValue}) {
    if (_isSecret(key)) {
      return (_secrets.containsKey(key) ? _secrets[key] : defaultValue) as T?;
    }
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> setSetting(String key, dynamic value) async {
    if (_isSecret(key)) {
      if (value == null) {
        _secrets.remove(key);
        await _secretStore!.delete(key);
      } else {
        _secrets[key] = value;
        await _secretStore!.write(key, jsonEncode(value));
      }
      return;
    }
    await _settingsBox.put(key, value);
  }

  // ─── Chat Sessions ─────────────────────────────

  List<Map<dynamic, dynamic>> getAllSessions() {
    return _sessionsBox.values
        .map((v) => Map<dynamic, dynamic>.from(v))
        .toList();
  }

  Future<void> saveSession(String id, Map<String, dynamic> data) async {
    await _sessionsBox.put(id, data);
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
    // Delete all messages for this session
    final keysToDelete = <dynamic>[];
    for (var key in _messagesBox.keys) {
      final msg = _messagesBox.get(key);
      if (msg is Map && msg['chatId'] == id) {
        keysToDelete.add(key);
      }
    }
    await _messagesBox.deleteAll(keysToDelete);
  }

  // ─── Chat Messages ─────────────────────────────

  List<Map<dynamic, dynamic>> getMessagesForChat(String chatId) {
    return _messagesBox.values
        .where((v) => v is Map && v['chatId'] == chatId)
        .map((v) => Map<dynamic, dynamic>.from(v))
        .toList();
  }

  Future<void> saveMessage(String id, Map<String, dynamic> data) async {
    await _messagesBox.put(id, data);
  }

  // ─── Tasks ─────────────────────────────────────

  List<Map<dynamic, dynamic>> getAllTasks() {
    return _tasksBox.values.map((v) => Map<dynamic, dynamic>.from(v)).toList();
  }

  Future<void> saveTask(String id, Map<String, dynamic> data) async {
    await _tasksBox.put(id, data);
  }

  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
  }
}
