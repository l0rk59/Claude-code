import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/gguf_split.dart';
import 'package:privatelm/services/hf_search_service.dart';

void main() {
  test('reads the part numbering the engine expects', () {
    final split = GgufSplit.parse('Qwen3.5-35B-A3B-Q8_0-00002-of-00003.gguf')!;
    expect(split.prefix, 'Qwen3.5-35B-A3B-Q8_0');
    expect(split.index, 2);
    expect(split.count, 3);
    expect(split.names, [
      'Qwen3.5-35B-A3B-Q8_0-00001-of-00003.gguf',
      'Qwen3.5-35B-A3B-Q8_0-00002-of-00003.gguf',
      'Qwen3.5-35B-A3B-Q8_0-00003-of-00003.gguf',
    ]);
    // A folder in front is ignored.
    expect(GgufSplit.parse('Q8_0/m-00001-of-00002.gguf')!.prefix, 'm');
    expect(GgufSplit.parse('model-Q4_K_M.gguf'), isNull);
    expect(GgufSplit.parse('m-00004-of-00003.gguf'), isNull);
    expect(GgufSplit.parse('m-00001-of-00001.gguf'), isNull);
  });

  test('later parts are part of a model, not models', () {
    expect(GgufSplit.isLaterPart('m-00002-of-00003.gguf'), isTrue);
    expect(GgufSplit.isLaterPart('m-00001-of-00003.gguf'), isFalse);
    expect(GgufSplit.isLaterPart('m.gguf'), isFalse);
    expect(GgufSplit.filesOf('m.gguf'), ['m.gguf']);
    expect(GgufSplit.filesOf('m-00001-of-00002.gguf'),
        ['m-00001-of-00002.gguf', 'm-00002-of-00002.gguf']);
  });

  test('parts download from the same folder', () {
    expect(
        GgufSplit.urlOf(
            'https://huggingface.co/u/r/resolve/main/Q8_0/m-00001-of-00002.gguf',
            'm-00002-of-00002.gguf'),
        'https://huggingface.co/u/r/resolve/main/Q8_0/m-00002-of-00002.gguf');
  });

  test('a model in parts weighs all of them on disk', () async {
    final dir = await Directory.systemTemp.createTemp('split');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/m-00001-of-00002.gguf').writeAsBytes(List.filled(10, 0));
    await File('${dir.path}/m-00002-of-00002.gguf').writeAsBytes(List.filled(32, 0));
    await File('${dir.path}/single.gguf').writeAsBytes(List.filled(7, 0));
    expect(await GgufSplit.bytesOnDisk('${dir.path}/m-00001-of-00002.gguf'), 42);
    expect(await GgufSplit.bytesOnDisk('${dir.path}/single.gguf'), 7);
    // A missing part counts as nothing.
    await File('${dir.path}/m-00002-of-00002.gguf').delete();
    expect(await GgufSplit.bytesOnDisk('${dir.path}/m-00001-of-00002.gguf'), 10);
  });

  test('Hugging Face lists a complete model in parts once, with its size', () {
    final details = HfSearchService.parseDetails(jsonEncode({
      'siblings': [
        {'rfilename': 'Q4_K_M/Big-Q4_K_M-00001-of-00002.gguf', 'lfs': {'size': 30000000000}},
        {'rfilename': 'Q4_K_M/Big-Q4_K_M-00002-of-00002.gguf', 'lfs': {'size': 12000000000}},
        // A part is missing: not offered.
        {'rfilename': 'Q8_0/Big-Q8_0-00001-of-00003.gguf', 'lfs': {'size': 30000000000}},
        {'rfilename': 'Big-Q2_K.gguf', 'lfs': {'size': 14000000000}},
      ],
    }));
    expect(details.files.map((f) => f.path),
        ['Big-Q2_K.gguf', 'Q4_K_M/Big-Q4_K_M-00001-of-00002.gguf']);
    final split = details.files.last;
    expect(split.bytes, 42000000000);
    expect(split.parts, 2);
    expect(split.quant, 'Q4_K_M');

    final model = HfSearchService.toModel(const HfRepo(id: 'u/Big-GGUF'), split);
    expect(model.filename, 'Big-Q4_K_M-00001-of-00002.gguf');
    expect(model.size, '42.00 GB');
    expect(
        GgufSplit.urlOf(model.url, GgufSplit.filesOf(model.filename).last),
        'https://huggingface.co/u/Big-GGUF/resolve/main/Q4_K_M/Big-Q4_K_M-00002-of-00002.gguf');
  });
}
