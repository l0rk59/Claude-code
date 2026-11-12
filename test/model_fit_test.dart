import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/model_fit.dart';

int mb(num n) => (n * 1000 * 1000).round();

void main() {
  test('8 GB phone', () {
    // Qwen 3.5 2B Q4_K_M
    expect(modelFit(modelBytes: mb(1281), totalRamGb: 8), ModelFit.ideal);
    // Qwen 3.5 4B Q4_K_M
    expect(modelFit(modelBytes: mb(2741), totalRamGb: 8), ModelFit.tight);
    // Kimi Moonlight 16B Q3_K_S
    expect(modelFit(modelBytes: mb(7100), totalRamGb: 8), ModelFit.tooBig);
  });

  test('4 GB phone', () {
    // Qwen 3.5 0.8B
    expect(modelFit(modelBytes: mb(533), totalRamGb: 4), ModelFit.ideal);
    // Qwen 3.5 2B
    expect(modelFit(modelBytes: mb(1281), totalRamGb: 4), ModelFit.tight);
    // Qwen 3.5 4B
    expect(modelFit(modelBytes: mb(2741), totalRamGb: 4), ModelFit.tooBig);
  });

  test('12 and 16 GB phones take bigger models', () {
    expect(modelFit(modelBytes: mb(2741), totalRamGb: 12), ModelFit.ideal);
    // Qwen 3.5 9B Q4_K_M
    expect(modelFit(modelBytes: mb(5681), totalRamGb: 12), ModelFit.tight);
    expect(modelFit(modelBytes: mb(5681), totalRamGb: 16), ModelFit.ideal);
  });

  test('unknown without a size or memory', () {
    expect(modelFit(modelBytes: 0, totalRamGb: 8), ModelFit.unknown);
    expect(modelFit(modelBytes: mb(500), totalRamGb: 0), ModelFit.unknown);
  });

  test('idealModelBytes is the edge of "ideal"', () {
    for (final ram in [4.0, 6.0, 8.0, 12.0, 16.0]) {
      final edge = idealModelBytes(ram);
      expect(modelFit(modelBytes: edge, totalRamGb: ram), ModelFit.ideal,
          reason: '$ram GB');
      expect(
          modelFit(modelBytes: edge + mb(50), totalRamGb: ram), ModelFit.tight,
          reason: '$ram GB');
    }
  });
}
