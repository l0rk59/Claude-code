import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/inference_android.dart';

String cpuinfo(List<String> parts) => [
      for (var i = 0; i < parts.length; i++)
        'processor\t: $i\nCPU implementer\t: 0x41\nCPU part\t: ${parts[i]}\n',
    ].join('\n');

void main() {
  test('skips the efficiency cores (Snapdragon 8 Gen 2: 1+4+3)', () {
    final info = cpuinfo([
      '0xd46', '0xd46', '0xd46', // Cortex-A510
      '0xd47', '0xd47', '0xd4d', '0xd4d', // A710, A715
      '0xd4e', // X3
    ]);
    expect(performanceCoreCount(cpuinfo: info), 5);
  });

  test('budget phones with only efficiency cores use four', () {
    expect(performanceCoreCount(cpuinfo: cpuinfo(List.filled(8, '0xd05'))), 4);
  });

  test('never more than six threads', () {
    // Snapdragon 8 Elite: eight Oryon cores, none of them efficiency cores.
    expect(performanceCoreCount(cpuinfo: cpuinfo(List.filled(8, '0x001'))), 6);
  });

  test('falls back to clock speeds when core types are missing', () {
    expect(
      performanceCoreCount(
        cpuinfo: 'Hardware : unknown\n',
        maxFreqs: [2000, 2000, 2000, 2000, 2800, 2800, 2800, 3360],
      ),
      4,
    );
  });

  test('null when nothing can be read', () {
    expect(performanceCoreCount(cpuinfo: '', maxFreqs: const []), isNull);
  });
}
