import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:privatelm/core/format.dart';
import 'package:privatelm/services/download_service.dart';

void main() {
  tearDown(() => Get.locale = null);

  test('decimals follow the app language', () {
    Get.locale = const Locale('en', 'US');
    expect(decimal(86.12), '86.1');
    expect(decimal(0.7, 2), '0.70');
    Get.locale = const Locale('fr', 'FR');
    expect(decimal(86.12), '86,1');
    expect(decimal(0.7, 2), '0,70');
    expect(decimal(12), '12,0');
  });

  test('memory reads like file sizes from 1 GB, in whole MB below', () {
    Get.locale = const Locale('fr', 'FR');
    expect(DownloadService.formatMemory(5627 * 1024 * 1024), contains('5,50'));
    expect(DownloadService.formatMemory(312 * 1024 * 1024), contains('312'));
    expect(
        DownloadService.formatMemory(312 * 1024 * 1024), isNot(contains(',')));
  });
}
