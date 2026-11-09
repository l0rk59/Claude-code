import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/sampling_presets.dart';

void main() {
  test('picks the family preset from the file name', () {
    expect(SamplingPreset.forModel('qwen3.5-2b-q4_k_m.gguf'),
        SamplingPreset.qwen35);
    expect(SamplingPreset.forModel('Qwen3.5-0.8B-Q4_K_M.gguf'),
        SamplingPreset.qwen35);
    expect(SamplingPreset.forModel('gemma-4-E2B-it-Q4_K_M.gguf'),
        SamplingPreset.gemma);
    expect(SamplingPreset.forModel('gemma-3-4b-it-q4_k_m.gguf'),
        SamplingPreset.gemma);
    expect(SamplingPreset.forModel('lfm2.5-1.2b-instruct-q4_k_m.gguf'),
        SamplingPreset.liquid);
  });

  test('other models keep the previous settings', () {
    for (final name in [
      'qwen2.5-3b-instruct-q4_k_m.gguf',
      'gemma-2-2b-it-abliterated-q4_k_m.gguf',
      'phi-4-mini-instruct-q4_k_m.gguf',
    ]) {
      expect(SamplingPreset.forModel(name), SamplingPreset.general,
          reason: name);
    }
  });
}
