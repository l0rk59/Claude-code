import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privatelm/controllers/model_controller.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/models/ai_model.dart';
import 'package:privatelm/services/gguf_architectures.dart';
import 'package:privatelm/services/hf_search_service.dart';

void main() {
  const repoInfo = {
    'id': 'unsloth/Qwen3.5-2B-GGUF',
    'gated': false,
    'gguf': {'architecture': 'qwen35', 'context_length': 262144},
    'siblings': [
      {'rfilename': '.gitattributes', 'size': 3060},
      {'rfilename': 'README.md', 'size': 4000},
      {
        'rfilename': 'Qwen3.5-2B-Q8_0.gguf',
        'size': 2012000000,
        'lfs': {'size': 2012000000}
      },
      {
        'rfilename': 'Qwen3.5-2B-Q4_K_M.gguf',
        'size': 135,
        'lfs': {'size': 1281000000}
      },
      {'rfilename': 'Qwen3.5-2B-UD-IQ2_M.gguf', 'size': 900000000},
      {
        'rfilename': 'BF16/big-BF16-00001-of-00003.gguf',
        'lfs': {'size': 9000000000}
      },
      {'rfilename': 'imatrix_unsloth.gguf', 'size': 5000000},
      {
        'rfilename': 'mmproj-F32.gguf',
        'lfs': {'size': 1326000000}
      },
      {
        'rfilename': 'mmproj-F16.gguf',
        'lfs': {'size': 668000000}
      },
    ],
  };
  final details = HfSearchService.parseDetails(jsonEncode(repoInfo));

  test('lists single GGUF files, smallest first, with their real size', () {
    expect(details.files.map((f) => f.path), [
      'mmproj-F16.gguf',
      'Qwen3.5-2B-UD-IQ2_M.gguf',
      'Qwen3.5-2B-Q4_K_M.gguf',
      'mmproj-F32.gguf',
      'Qwen3.5-2B-Q8_0.gguf',
    ]);
    expect(details.files[2].bytes, 1281000000);
    expect(details.models.map((f) => f.quant), ['UD-IQ2_M', 'Q4_K_M', 'Q8_0']);
  });

  test('reads the quantisation from the file name', () {
    String quant(String name) => HfFile(name, 1).quant;
    expect(quant('Qwen3.5-2B-Q4_K_M.gguf'), 'Q4_K_M');
    expect(quant('Qwen3.5-2B-UD-IQ2_M.gguf'), 'UD-IQ2_M');
    expect(quant('gemma-4-E2B-it-Q8_0.gguf'), 'Q8_0');
    expect(quant('Phi-4-mini-instruct.Q8_0.gguf'), 'Q8_0');
    expect(quant('gemma-3-4b-it-q4_0.gguf'), 'Q4_0');
    expect(quant('mmproj-F16.gguf'), 'F16');
    expect(quant('model.gguf'), '');
  });

  test('pairs the F16 vision file', () {
    expect(details.mmproj!.path, 'mmproj-F16.gguf');
    expect(
        const HfRepoDetails(files: [HfFile('a-Q4_0.gguf', 1)]).mmproj, isNull);
  });

  test('knows whether the engine can run the model', () {
    expect(details.gated, isFalse);
    expect(details.architecture, 'qwen35');
    expect(details.supported, isTrue);

    final lfm3 = HfSearchService.parseDetails(jsonEncode({
      'gated': 'manual',
      'gguf': {'architecture': 'lfm3'},
      'siblings': <Object>[],
    }));
    expect(lfm3.gated, isTrue);
    expect(lfm3.supported, isFalse);
    // No GGUF metadata: don't rule the model out.
    expect(const HfRepoDetails().supported, isTrue);
  });

  test('suggests the file that suits the phone', () {
    // 8 GB: Q4_K_M runs well.
    expect(details.recommended(8)!.quant, 'Q4_K_M');
    // 4 GB: only the smallest does.
    expect(details.recommended(4)!.quant, 'UD-IQ2_M');
    // 2 GB: nothing does.
    expect(details.recommended(2), isNull);
    // No Q4_K_M: the biggest that runs well.
    const noQ4 = HfRepoDetails(files: [
      HfFile('m-Q3_K_M.gguf', 1100000000),
      HfFile('m-Q8_0.gguf', 2012000000),
      HfFile('m-BF16.gguf', 9000000000),
    ]);
    expect(noQ4.recommended(8)!.quant, 'Q8_0');
  });

  test('parses search results', () {
    final repos = HfSearchService.parseRepos(jsonEncode([
      {'id': 'unsloth/Qwen3.5-2B-GGUF', 'downloads': 1200000, 'likes': 310},
      {'id': 'me/private-GGUF', 'private': true},
      {'downloads': 3},
    ]));
    expect(repos.map((r) => r.id), ['unsloth/Qwen3.5-2B-GGUF']);
    expect(repos[0].name, 'Qwen3.5-2B');
    expect(repos[0].owner, 'unsloth');
    expect(repos[0].downloads, 1200000);
    expect(const HfRepo(id: 'google/gemma-3-4b-it-qat-q4_0-gguf').name,
        'gemma-3-4b-it-qat-q4_0');
  });

  test('builds a downloadable model', () {
    const repo = HfRepo(id: 'unsloth/Qwen3.5-2B-GGUF');
    final model = HfSearchService.toModel(
      repo,
      details.models.firstWhere((f) => f.quant == 'Q4_K_M'),
      mmproj: details.mmproj,
    );
    expect(model.name, 'Qwen3.5-2B (Q4_K_M)');
    expect(model.filename, 'Qwen3.5-2B-Q4_K_M.gguf');
    expect(model.url,
        'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf');
    expect(model.size, '1.28 GB + 668 MB vision');
    expect(model.isCustom, isTrue);
    expect(model.isVision, isTrue);
    expect(model.mmprojFilename, 'qwen3.5-2b-mmproj-f16.gguf');
    expect(model.mmprojUrl, endsWith('/resolve/main/mmproj-F16.gguf'));

    // Survives being saved with the user's models.
    final saved = AiModel.fromMap(model.toMap());
    expect(saved.isCustom, isTrue);
    expect(saved.mmprojUrl, model.mmprojUrl);
  });

  test('recognises a model the catalogue already lists', () {
    final catalog = AppConstants.availableModels.map(AiModel.fromMap).toList();
    // Same file as the catalogue's Qwen 3.5 2B, which is saved under a
    // lowercase name.
    final same = HfSearchService.toModel(
      const HfRepo(id: 'unsloth/Qwen3.5-2B-GGUF'),
      details.models.firstWhere((f) => f.quant == 'Q4_K_M'),
      mmproj: details.mmproj,
    );
    expect(ModelController.findListed(catalog, same)?.filename,
        'qwen3.5-2b-q4_k_m.gguf');

    // Another publisher's copy with the same file name is the same model
    // on disk, whatever its case.
    final copy = HfSearchService.toModel(
      const HfRepo(id: 'someone/Qwen3.5-2B-GGUF'),
      const HfFile('QWEN3.5-2B-Q4_K_M.gguf', 1281000000),
    );
    expect(ModelController.findListed(catalog, copy)?.filename,
        'qwen3.5-2b-q4_k_m.gguf');

    // Another size of the same model is a different file.
    final other = HfSearchService.toModel(
      const HfRepo(id: 'unsloth/Qwen3.5-2B-GGUF'),
      details.models.firstWhere((f) => f.quant == 'Q8_0'),
    );
    expect(ModelController.findListed(catalog, other), isNull);
  });

  test('searches GGUF repositories by downloads', () async {
    late Uri asked;
    final service = HfSearchService(
      client: MockClient((request) async {
        asked = request.url;
        return http.Response(
            jsonEncode([
              {'id': 'a/b-GGUF', 'downloads': 5}
            ]),
            200);
      }),
    );
    final repos = await service.search(' qwen 3.5 ');
    expect(repos.single.id, 'a/b-GGUF');
    expect(asked.host, 'huggingface.co');
    expect(asked.queryParameters['search'], 'qwen 3.5');
    expect(asked.queryParameters['filter'], 'gguf');
    expect(asked.queryParameters['sort'], 'downloads');
  });

  test('asks for a repository with its file sizes', () async {
    late Uri asked;
    final service = HfSearchService(
      client: MockClient((request) async {
        asked = request.url;
        return http.Response(jsonEncode(repoInfo), 200);
      }),
    );
    final got = await service.details('unsloth/Qwen3.5-2B-GGUF');
    expect(asked.path, '/api/models/unsloth/Qwen3.5-2B-GGUF');
    expect(asked.queryParameters['blobs'], 'true');
    expect(got.files, hasLength(5));
  });

  test('reports a failed request', () async {
    final service = HfSearchService(
        client: MockClient((_) async => http.Response('nope', 503)));
    expect(service.search('x'), throwsA(isA<http.ClientException>()));
  });

  test('the architecture list matches the bundled llama.cpp', () {
    final source = File('local_plugins/llama_flutter_android/android/src/main/'
            'cpp/llama.cpp/src/llama-arch.cpp')
        .readAsStringSync();
    final table = RegExp(r'LLM_ARCH_NAMES\s*=\s*\{(.*?)\n\};', dotAll: true)
        .firstMatch(source)![1]!;
    final names = RegExp(r'\{\s*LLM_ARCH_\w+\s*,\s*"([^"]+)"\s*\}')
        .allMatches(table)
        .map((m) => m[1]!)
        .where((name) => name != '(unknown)')
        .toSet();
    expect(names, isNotEmpty);
    expect(ggufArchitectures, names);
  });
}
