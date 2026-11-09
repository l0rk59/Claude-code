import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/models/ai_model.dart';

void main() {
  const catalog = AppConstants.availableModels;

  test('every model has a unique file name', () {
    final names = catalog.map((m) => m['filename']!.toLowerCase()).toList();
    expect(names.toSet().length, names.length);
  });

  test('every model downloads from Hugging Face over HTTPS', () {
    for (final m in catalog) {
      expect(m['url'], startsWith('https://huggingface.co/'),
          reason: m['name']);
      if (m['mmproj_url'] != null) {
        expect(m['mmproj_url'], startsWith('https://huggingface.co/'),
            reason: m['name']);
      }
    }
  });

  test('every size is in MB or GB', () {
    final size = RegExp(r'^[\d.]+ (MB|GB)( \+ [\d.]+ (MB|GB) vision)?$');
    for (final m in catalog) {
      expect(m['size'], matches(size), reason: m['name']);
    }
  });

  test('GGUF vision models come with their vision file', () {
    for (final m in catalog.map(AiModel.fromMap)) {
      if (m.runtime != AiModel.runtimeLlama || !m.isVision) continue;
      expect(m.mmprojFilename, isNotEmpty, reason: m.name);
      expect(m.mmprojUrl, isNotEmpty, reason: m.name);
    }
  });

  test('each filter has at most one recommended pick', () {
    final counts = <String, int>{};
    for (final m in catalog.map(AiModel.fromMap)) {
      for (final f in m.recommendedFor) {
        counts[f] = (counts[f] ?? 0) + 1;
      }
    }
    expect(counts.values.every((c) => c == 1), isTrue, reason: '$counts');
  });

  test('superseded models are never the recommended pick', () {
    for (final m in catalog.map(AiModel.fromMap)) {
      if (m.isLegacy) expect(m.recommendedFor, isEmpty, reason: m.name);
    }
  });

  test('the legacy flag survives a round trip', () {
    final m = AiModel.fromMap(const {
      'name': 'Old',
      'filename': 'old.gguf',
      'url': '',
      'size': '1 GB',
      'description': '',
      'legacy': 'true',
    });
    expect(m.isLegacy, isTrue);
    expect(AiModel.fromMap(m.toMap()).isLegacy, isTrue);
    expect(m.copyWith(name: 'Renamed').isLegacy, isTrue);
  });
}
