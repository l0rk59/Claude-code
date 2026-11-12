import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:privatelm/services/cluster_service.dart';

void main() {
  const phone = ClusterWorker(
      name: 'Pixel', host: '192.168.1.11', port: 50052, ramMb: 6000, bandwidth: 9);
  const laptop = ClusterWorker(
      name: '192.168.1.20', host: '192.168.1.20', port: 50052, ramMb: 12288, computer: true);

  test('a computer gives what its owner chose, a phone three quarters', () {
    expect(ClusterService.capacityMb(laptop), 12288);
    expect(ClusterService.capacityMb(phone), 4500);
    // Paired by IP, never reported its memory.
    const unknown = ClusterWorker(name: 'x', host: 'x', port: 1);
    expect(ClusterService.capacityMb(unknown), 1500);
  });

  test('a computer ranks ahead of this phone, a measured speed is kept', () {
    expect(ClusterService.speedOf(phone, 14), 9);
    expect(ClusterService.speedOf(laptop, 6), 12);
    expect(ClusterService.speedOf(laptop, 14), 17.5);
    const unknown = ClusterWorker(name: 'x', host: 'x', port: 1);
    expect(ClusterService.speedOf(unknown, 14), 4);
  });

  test('3 phones and a laptop hold a model none of them could alone', () {
    // 8 GB phones with about 5 GB free each, a laptop giving 16 GB.
    final workers = [
      for (var i = 1; i <= 2; i++)
        ClusterWorker(name: 'p$i', host: 'p$i', port: 50052, ramMb: 5000, bandwidth: 8),
      const ClusterWorker(
          name: 'pc', host: 'pc', port: 50052, ramMb: 16384, computer: true),
    ];
    const masterMb = 5000 * 0.7;
    final totalMb = masterMb +
        workers.fold<double>(0, (a, w) => a + ClusterService.capacityMb(w));
    // 3.5 + 3.75 + 3.75 + 16 = 27 GB: a 24 GB model (x1.1) just fits.
    expect(totalMb, closeTo(27384, 1));
    expect(24 * 1024 * 1.1 <= totalMb, isTrue);
    expect(25 * 1024 * 1.1 <= totalMb, isFalse);
  });

  test('reads an address with or without a port', () {
    expect(ClusterService.parseEndpoint(' 192.168.1.20 '),
        (host: '192.168.1.20', port: LlamaCluster.defaultPort));
    expect(ClusterService.parseEndpoint('192.168.1.20:50060'),
        (host: '192.168.1.20', port: 50060));
    expect(ClusterService.parseEndpoint('my-laptop.local:50052'),
        (host: 'my-laptop.local', port: 50052));
    expect(ClusterService.parseEndpoint(''), isNull);
    expect(ClusterService.parseEndpoint('192.168.1.20:abc'), isNull);
    expect(ClusterService.parseEndpoint('192.168.1.20:99999'), isNull);
    expect(ClusterService.parseEndpoint('my laptop'), isNull);
  });

  test('a computer stays a computer once saved', () {
    final saved = ClusterWorker.fromMap(laptop.toMap());
    expect(saved.computer, isTrue);
    expect(saved.ramMb, 12288);
    expect(saved.movedTo('192.168.1.30', 50052).computer, isTrue);
    // Workers saved by an earlier version have no such field.
    expect(
        ClusterWorker.fromMap(const {'host': 'a', 'port': 1}).computer, isFalse);
  });

  test('the release named to the user is the one the plugin is built from', () {
    final changelog =
        File('local_plugins/llama_flutter_android/CHANGELOG.md').readAsStringSync();
    final vendored = RegExp(r'Vendored llama\.cpp updated to release (b\d+)')
        .firstMatch(changelog)![1];
    expect(LlamaCluster.llamaCppRelease, vendored);
  });
}
