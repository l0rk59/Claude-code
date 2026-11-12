import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/controllers/model_controller.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/models/ai_model.dart';
import 'package:privatelm/services/download_service.dart';

const _gb = 1024 * 1024 * 1024;

void main() {
  AiModel model(String size) => AiModel(
      name: 'm',
      filename: 'm.gguf',
      url: '',
      size: size,
      description: '',
      template: 'chatml');

  test('counts the model and its vision file', () {
    expect(ModelController.declaredDownloadBytes(model('5.68 GB + 918 MB vision')),
        5680000000 + 918000000);
    expect(ModelController.declaredDownloadBytes(model('731 MB')), 731000000);
    expect(ModelController.declaredDownloadBytes(model('')), 0);
  });

  test('every catalogue model states how much it downloads', () {
    for (final m in AppConstants.availableModels.map(AiModel.fromMap)) {
      expect(ModelController.declaredDownloadBytes(m), greaterThan(0),
          reason: m.name);
    }
  });

  test('refuses a download that cannot fit', () {
    String? problem(int needed, int? free) => DownloadService.storageProblem(
        neededBytes: needed, freeBytes: free);

    expect(problem(22 * _gb, 10 * _gb), contains('storage'));
    // Fits, with room to spare.
    expect(problem(5 * _gb, 64 * _gb), isNull);
    // Would leave the phone with nothing: refused too.
    expect(problem(5 * _gb, 5 * _gb + 1024), isNotNull);
    // Unknown free space or size: don't block.
    expect(problem(5 * _gb, null), isNull);
    expect(problem(0, 1024), isNull);
  });
}
