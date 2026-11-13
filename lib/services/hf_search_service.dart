import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_model.dart';
import 'gguf_architectures.dart';
import 'gguf_split.dart';
import 'model_fit.dart';

/// A model repository on Hugging Face.
class HfRepo {
  /// "owner/name".
  final String id;
  final int downloads;
  final int likes;

  const HfRepo({required this.id, this.downloads = 0, this.likes = 0});

  String get owner => id.contains('/') ? id.split('/').first : '';

  /// The repository name without the "-GGUF" suffix.
  String get name => (id.contains('/') ? id.split('/').last : id)
      .replaceAll(RegExp(r'[-_.]?gguf$', caseSensitive: false), '');
}

/// What a repository holds: its GGUF files and whether the app can use them.
class HfRepoDetails {
  /// Its publisher asks to accept a licence first: downloading needs a
  /// Hugging Face token whose account has accepted it.
  final bool gated;

  /// For a [gated] repository: whether the user's token gives access to
  /// its files. Null when it wasn't checked (no token, or not gated).
  final bool? accessible;

  /// The model's GGUF architecture ("qwen35", "gemma4"…), '' when unknown.
  final String architecture;

  /// Every single-file GGUF, smallest first.
  final List<HfFile> files;

  const HfRepoDetails({
    this.gated = false,
    this.accessible,
    this.architecture = '',
    this.files = const [],
  });

  /// Whether the app may download from it now.
  bool get downloadable => !gated || accessible == true;

  HfRepoDetails withAccess(bool access) => HfRepoDetails(
      gated: gated,
      accessible: access,
      architecture: architecture,
      files: files);

  /// The model files, without the vision file.
  List<HfFile> get models => files.where((f) => !f.isMmproj).toList();

  /// The vision file to pair with the models: F16 when there is one, else
  /// Q8_0, else the smallest.
  HfFile? get mmproj {
    final projectors = files.where((f) => f.isMmproj).toList();
    if (projectors.isEmpty) return null;
    for (final wanted in ['F16', 'Q8_0']) {
      for (final f in projectors) {
        if (f.quant == wanted) return f;
      }
    }
    return projectors.first;
  }

  /// False when the app's engine can't run this architecture. Unknown
  /// architectures get the benefit of the doubt.
  bool get supported =>
      architecture.isEmpty || ggufArchitectures.contains(architecture);

  /// The file to suggest on a phone with [totalRamGb]: Q4_K_M when it runs
  /// well, else the biggest file that does; null when none does.
  HfFile? recommended(double totalRamGb) {
    final ideal = models
        .where((f) =>
            modelFit(modelBytes: f.bytes, totalRamGb: totalRamGb) ==
            ModelFit.ideal)
        .toList();
    if (ideal.isEmpty) return null;
    return ideal.firstWhere((f) => f.quant == 'Q4_K_M',
        orElse: () => ideal.last);
  }
}

/// A GGUF file in a repository.
class HfFile {
  /// For a model in parts, its first part.
  final String path;

  /// The whole model's size: all parts together.
  final int bytes;

  /// How many files the model is published in (1: a single file).
  final int parts;

  const HfFile(this.path, this.bytes, {this.parts = 1});

  String get basename => path.split('/').last;

  /// The vision projector that goes with the repository's models.
  bool get isMmproj => basename.toLowerCase().contains('mmproj');

  /// "Q4_K_M", "UD-IQ2_M", "F16"…, or '' when the name has none.
  String get quant {
    final match = RegExp(
            r'((?:UD-)?(?:I?Q\d+(?:_[A-Z0-9]+)*|BF16|F16|F32|FP16))(?=\.gguf$|[-.])',
            caseSensitive: false)
        .allMatches(basename)
        .lastOrNull;
    return match == null ? '' : match[1]!.toUpperCase();
  }
}

/// Searches Hugging Face for GGUF models and turns a chosen file into a
/// model the app can download.
class HfSearchService {
  static const _host = 'huggingface.co';

  final http.Client _client;

  /// The user's Hugging Face token, read on each request ('' or null: none).
  final String? Function()? token;

  HfSearchService({http.Client? client, this.token})
      : _client = client ?? http.Client();

  Map<String, String> get _headers {
    final value = token?.call()?.trim() ?? '';
    return value.isEmpty ? const {} : {'Authorization': 'Bearer $value'};
  }

  /// The account a token belongs to. Null when Hugging Face refuses it.
  /// Throws when Hugging Face can't be reached.
  Future<String?> whoAmI(String token) async {
    final response = await _client.get(
      Uri.https(_host, '/api/whoami-v2'),
      headers: {'Authorization': 'Bearer ${token.trim()}'},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) return null;
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Hugging Face returned ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data is Map ? '${data['name'] ?? ''}' : null;
  }

  /// Whether the user's token may download [path] of [repoId]: Hugging Face
  /// answers a file request with the file (or a redirect to it) once the
  /// account has accepted the licence, and with 401/403 before.
  Future<bool> canDownload(String repoId, String path) async {
    final request =
        http.Request('HEAD', Uri.https(_host, '/$repoId/resolve/main/$path'))
          ..followRedirects = false
          ..headers.addAll(_headers);
    final response =
        await _client.send(request).timeout(const Duration(seconds: 20));
    await response.stream.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 400;
  }

  /// GGUF repositories matching [query], most downloaded first.
  Future<List<HfRepo>> search(String query, {int limit = 30}) async {
    final uri = Uri.https(_host, '/api/models', {
      'search': query.trim(),
      'filter': 'gguf',
      'sort': 'downloads',
      'direction': '-1',
      'limit': '$limit',
    });
    return parseRepos(await _get(uri));
  }

  /// The GGUF files of [repoId] and whether the app can use them.
  Future<HfRepoDetails> details(String repoId) async {
    // "blobs" adds the file sizes.
    final uri = Uri.https(_host, '/api/models/$repoId', {'blobs': 'true'});
    final details = parseDetails(await _get(uri));
    // Behind a licence: with a token, find out whether it opens the door.
    if (details.gated && _headers.isNotEmpty && details.models.isNotEmpty) {
      try {
        return details
            .withAccess(await canDownload(repoId, details.models.first.path));
      } catch (_) {
        return details;
      }
    }
    return details;
  }

  Future<String> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Hugging Face returned ${response.statusCode}', uri);
    }
    return utf8.decode(response.bodyBytes);
  }

  static List<HfRepo> parseRepos(String body) {
    final data = jsonDecode(body);
    if (data is! List) return const [];
    return [
      for (final item in data.whereType<Map>())
        if (item['id'] is String && item['private'] != true)
          HfRepo(
            id: item['id'] as String,
            downloads: (item['downloads'] as num?)?.toInt() ?? 0,
            likes: (item['likes'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// Reads a repository: its single-file GGUFs (the app can't load models
  /// split in parts), smallest first.
  static HfRepoDetails parseDetails(String body) {
    final data = jsonDecode(body);
    if (data is! Map) return const HfRepoDetails();
    final files = <HfFile>[];
    // Parts of the same model, by first part: present parts and size.
    final parts = <String, ({int found, int count, int bytes})>{};
    for (final item
        in (data['siblings'] as List? ?? const []).whereType<Map>()) {
      final path = item['rfilename'];
      if (path is! String) continue;
      final lower = path.toLowerCase();
      if (!lower.endsWith('.gguf') || lower.contains('imatrix')) continue;
      final bytes = ((item['lfs'] as Map?)?['size'] as num? ??
              item['size'] as num? ??
              0)
          .toInt();
      final split = GgufSplit.parse(path);
      if (split == null) {
        files.add(HfFile(path, bytes));
        continue;
      }
      final slash = path.lastIndexOf('/');
      final first = '${path.substring(0, slash + 1)}${split.names.first}';
      final seen = parts[first];
      parts[first] = (
        found: (seen?.found ?? 0) + 1,
        count: split.count,
        bytes: (seen?.bytes ?? 0) + bytes,
      );
    }
    // A model whose parts aren't all there can't be loaded.
    for (final e in parts.entries) {
      if (e.value.found == e.value.count) {
        files.add(HfFile(e.key, e.value.bytes, parts: e.value.count));
      }
    }
    files.sort((a, b) => a.bytes.compareTo(b.bytes));
    return HfRepoDetails(
      // false, or "auto" / "manual" when gated.
      gated: data['gated'] != null && data['gated'] != false,
      architecture: ((data['gguf'] as Map?)?['architecture'] as String?) ?? '',
      files: files,
    );
  }

  /// A downloadable model for [file] of [repo], with [mmproj] as its vision
  /// file when the repository has one.
  static AiModel toModel(HfRepo repo, HfFile file, {HfFile? mmproj}) {
    String url(HfFile f) =>
        Uri.https(_host, '/${repo.id}/resolve/main/${f.path}').toString();
    final slug =
        repo.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]+'), '-');
    return AiModel(
      name: file.quant.isEmpty ? repo.name : '${repo.name} (${file.quant})',
      filename: file.basename,
      url: url(file),
      size: mmproj == null
          ? catalogSize(file.bytes)
          : '${catalogSize(file.bytes)} + ${catalogSize(mmproj.bytes)} vision',
      description: 'Hugging Face · ${repo.id}',
      template: 'chatml',
      isCustom: true,
      isVision: mmproj != null,
      // Vision files are often just "mmproj-F16.gguf": prefix the model's
      // name so two models don't share one.
      mmprojFilename:
          mmproj == null ? '' : '$slug-${mmproj.basename.toLowerCase()}',
      mmprojUrl: mmproj == null ? '' : url(mmproj),
    );
  }

  /// A size in the catalogue's format (decimal units): "533 MB", "1.28 GB".
  static String catalogSize(int bytes) => bytes >= 1000 * 1000 * 1000
      ? '${(bytes / 1e9).toStringAsFixed(2)} GB'
      : '${(bytes / 1e6).round()} MB';
}
