import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/controllers/cloud_model_controller.dart';
import 'package:privatelm/controllers/settings_controller.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/services/app_log_service.dart';
import 'package:privatelm/services/cloud_service.dart';
import 'package:privatelm/services/hive_service.dart';

void main() {
  late Directory dir;
  late SettingsController settings;
  late CloudModelController cloud;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('connect_test');
    Hive.init(dir.path);
    Get.put(await HiveService().init());
    Get.put(AppLogService());
    settings = Get.put(SettingsController());
    cloud = Get.put(CloudModelController());
  });

  tearDown(() async {
    Get.reset();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('connecting to a computer makes it the chat model, with no key',
      () async {
    await cloud.connectComputer(
      name: 'llama.cpp · 192.168.1.20',
      baseUrl: 'http://192.168.1.20:8080/v1/',
      model: 'Qwen3.5-35B-A3B-Q4_K_M.gguf',
    );

    expect(settings.inferenceMode.value, 'cloud');
    expect(settings.cloudProvider.value, 'custom');
    expect(settings.customCloudBaseUrl.value, 'http://192.168.1.20:8080/v1');
    expect(settings.customCloudModel.value, 'Qwen3.5-35B-A3B-Q4_K_M.gguf');
    expect(settings.customCloudKey.value, '');
    expect(cloud.isConfigured('custom'), isTrue);
    // The chat can send right away: nothing else to set up.
    expect(CloudService().isConfigured, isTrue);
    expect(
        Get.find<HiveService>().getSetting(AppConstants.keyCustomCloudBaseUrl),
        'http://192.168.1.20:8080/v1');
  });

  test('a computer added twice is listed once; another one is added',
      () async {
    await cloud.connectComputer(
        name: 'PC', baseUrl: 'http://192.168.1.20:8080/v1', model: 'a');
    await cloud.connectComputer(
        name: 'PC', baseUrl: 'http://192.168.1.20:8080/v1', model: 'b');
    expect(cloud.customProfiles, hasLength(1));
    expect(cloud.customProfiles.single['model'], 'b');

    await cloud.connectComputer(
        name: 'Mac', baseUrl: 'http://192.168.1.30:11434/v1', model: 'c');
    expect(cloud.customProfiles, hasLength(2));
    expect(settings.customCloudBaseUrl.value, 'http://192.168.1.30:11434/v1');

    // Back to the first one: its entry is reused, not duplicated.
    await cloud.connectComputer(
        name: 'PC', baseUrl: 'http://192.168.1.20:8080/v1', model: 'a');
    expect(cloud.customProfiles, hasLength(2));
    expect(settings.customCloudBaseUrl.value, 'http://192.168.1.20:8080/v1');
    expect(settings.customCloudModel.value, 'a');
  });
}
