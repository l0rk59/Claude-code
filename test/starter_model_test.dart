import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/controllers/model_controller.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/models/ai_model.dart';

void main() {
  final catalog = AppConstants.availableModels.map(AiModel.fromMap).toList();
  String? starter(double ramGb) =>
      ModelController.pickStarter(catalog, ramGb)?.filename;

  test('suggests a model that suits the phone', () {
    expect(starter(3), 'qwen3.5-0.8b-q4_k_m.gguf');
    expect(starter(4), 'qwen3.5-0.8b-q4_k_m.gguf');
    expect(starter(6), 'qwen3.5-2b-q4_k_m.gguf');
    expect(starter(8), 'qwen3.5-2b-q4_k_m.gguf');
    expect(starter(12), 'qwen3.5-4b-q4_k_m.gguf');
    expect(starter(16), 'qwen3.5-4b-q4_k_m.gguf');
  });

  test('starters exist in the catalogue', () {
    for (final ram in [3.0, 8.0, 16.0]) {
      expect(starter(ram), isNotNull);
    }
  });

  test('without its starters, suggests nothing', () {
    final others =
        catalog.where((m) => !m.filename.startsWith('qwen3.5-')).toList();
    expect(ModelController.pickStarter(others, 8), isNull);
  });
}
