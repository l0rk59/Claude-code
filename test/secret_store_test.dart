import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/services/hive_service.dart';
import 'package:privatelm/services/secret_store.dart';

/// A keystore that can't be opened, as on a phone whose keystore is broken.
class _BrokenStore implements SecretStore {
  @override
  Future<Map<String, String>> readAll() => throw Exception('keystore broken');
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('secret_test');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<Box> oldSettings(Map<String, dynamic> values) async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    await box.putAll(values);
    await box.close();
    return box;
  }

  test('keys saved by an earlier version move to the keystore', () async {
    await oldSettings({
      AppConstants.keyOpenaiKey: 'sk-old',
      AppConstants.keyCustomCloudProfiles: [
        {'name': 'PC', 'baseUrl': 'http://192.168.1.20:8080/v1', 'apiKey': 'k1'},
      ],
      AppConstants.keyContextSize: 4096,
    });
    final store = MemorySecretStore();
    final hive = await HiveService(secrets: store).init();

    expect(hive.getSetting<String>(AppConstants.keyOpenaiKey), 'sk-old');
    final profiles =
        hive.getSetting<List>(AppConstants.keyCustomCloudProfiles)!;
    expect((profiles.single as Map)['apiKey'], 'k1');
    // Gone from the settings file, kept in the keystore.
    expect(hive.settingsBox.containsKey(AppConstants.keyOpenaiKey), isFalse);
    expect(hive.settingsBox.containsKey(AppConstants.keyCustomCloudProfiles),
        isFalse);
    expect(jsonDecode(store.values[AppConstants.keyOpenaiKey]!), 'sk-old');
    // Ordinary settings stay where they were.
    expect(hive.getSetting<int>(AppConstants.keyContextSize), 4096);
    expect(hive.settingsBox.get(AppConstants.keyContextSize), 4096);
  });

  test('new keys go to the keystore only, and can be removed', () async {
    final store = MemorySecretStore();
    final hive = await HiveService(secrets: store).init();

    await hive.setSetting(AppConstants.keyHfToken, 'hf_abc');
    expect(hive.getSetting<String>(AppConstants.keyHfToken), 'hf_abc');
    expect(hive.settingsBox.containsKey(AppConstants.keyHfToken), isFalse);
    expect(store.values.containsKey(AppConstants.keyHfToken), isTrue);

    await hive.setSetting(AppConstants.keyHfToken, null);
    expect(hive.getSetting<String>(AppConstants.keyHfToken), isNull);
    expect(hive.getSetting<String>(AppConstants.keyHfToken, defaultValue: ''),
        '');
    expect(store.values.containsKey(AppConstants.keyHfToken), isFalse);
  });

  test('the keystore wins over a stale copy left in the settings', () async {
    await oldSettings({AppConstants.keyNvidiaKey: 'stale'});
    final store = MemorySecretStore(
        {AppConstants.keyNvidiaKey: jsonEncode('current')});
    final hive = await HiveService(secrets: store).init();
    expect(hive.getSetting<String>(AppConstants.keyNvidiaKey), 'current');
    expect(hive.settingsBox.containsKey(AppConstants.keyNvidiaKey), isFalse);
  });

  test('keys survive a restart', () async {
    final store = MemorySecretStore();
    final first = await HiveService(secrets: store).init();
    await first.setSetting(AppConstants.keyDeepSeekKey, 'ds-1');
    await Hive.close();

    final second = await HiveService(secrets: store).init();
    expect(second.getSetting<String>(AppConstants.keyDeepSeekKey), 'ds-1');
  });

  test('a broken keystore leaves the keys where they are', () async {
    await oldSettings({AppConstants.keyOpenaiKey: 'sk-old'});
    final hive = await HiveService(secrets: _BrokenStore()).init();
    expect(hive.getSetting<String>(AppConstants.keyOpenaiKey), 'sk-old');
    expect(hive.settingsBox.get(AppConstants.keyOpenaiKey), 'sk-old');
    await hive.setSetting(AppConstants.keyOpenaiKey, 'sk-new');
    expect(hive.settingsBox.get(AppConstants.keyOpenaiKey), 'sk-new');
  });
}
