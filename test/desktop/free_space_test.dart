import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/download_native.dart';

void main() {
  test('reads the free space df reports', () {
    expect(
        parseDfAvailable('Filesystem 1024-blocks Used Available Capacity Mounted on\n'
            '/dev/nvme0n1p2 488245288 201234567 262130000 44% /\n'),
        262130000 * 1024);
    expect(parseDfAvailable(''), isNull);
    expect(parseDfAvailable('header only'), isNull);
  });

  test('the free space of a real folder', () async {
    final free = await freeSpaceBytes(Directory.systemTemp.path);
    expect(free, isNotNull);
    expect(free, greaterThan(0));
  });
}
