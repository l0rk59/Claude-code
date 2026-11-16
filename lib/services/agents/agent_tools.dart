import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../document_extractor_service.dart';
import '../document_library.dart';
import '../lan_server_finder.dart';
import '../web_search_service.dart';
import 'calculator.dart';

/// Something an agent can do. Tools that read are free to use; tools that
/// write a file, run code or remember something ask the user first (see
/// [AgentConfirmation]), so a web page that slips instructions to the
/// model can't make it do harm behind the user's back.
class AgentTool {
  /// What the model writes to call it.
  final String name;

  /// What the model reads about it (English: small models follow English
  /// instructions best).
  final String description;

  /// Its arguments: name → what to put there.
  final Map<String, String> parameters;

  /// Arguments that may be left out.
  final Set<String> optional;

  /// What the user sees while it runs ("Searching the web: …").
  final String Function(Map<String, dynamic> args) label;

  /// Does it. Returns what the model reads back; throws to report a
  /// failure.
  final Future<String> Function(Map<String, dynamic> args) run;

  const AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.label,
    required this.run,
    this.optional = const {},
  });

  /// The arguments as a JSON schema (for models that call tools natively).
  Map<String, dynamic> get schema => {
        'type': 'object',
        'properties': {
          for (final e in parameters.entries)
            e.key: {'type': 'string', 'description': e.value},
        },
        'required': [
          for (final k in parameters.keys)
            if (!optional.contains(k)) k,
        ],
      };

  /// How the tool is presented to the model.
  String get signature {
    final args = parameters.entries
        .map((e) => '"${e.key}": ${e.value}')
        .join(', ');
    return '- $name: $description Arguments: {$args}';
  }
}

/// The tools of one run, and what they found (shown as sources under the
/// answer).
class AgentToolbox {
  static const webSearch = 'web_search';
  static const readPage = 'read_page';
  static const searchDocuments = 'search_documents';
  static const calculator = 'calculator';
  static const dateTime = 'current_datetime';
  static const remember = 'remember';
  static const listFiles = 'list_files';
  static const readFile = 'read_file';
  static const writeFile = 'write_file';
  static const runPython = 'run_python';
  static const askAssistant = 'ask_assistant';

  /// Every tool, in the order they are offered.
  static const all = [
    webSearch,
    readPage,
    searchDocuments,
    calculator,
    dateTime,
    remember,
    listFiles,
    readFile,
    writeFile,
    runPython,
    askAssistant,
  ];

  /// Tools that ask the user before acting.
  static const asksFirst = {remember, writeFile, runPython};

  /// A word for the tool, in lists of an assistant's tools (the three
  /// file tools share one).
  static String shortTitle(String tool) => switch (tool) {
        webSearch => 'Web'.tr,
        readPage => 'Pages'.tr,
        searchDocuments => 'Documents'.tr,
        calculator => 'Calculation'.tr,
        dateTime => 'Date'.tr,
        remember => 'Memory'.tr,
        listFiles || readFile || writeFile => 'Files'.tr,
        runPython => 'Python',
        askAssistant => 'Assistants'.tr,
        _ => tool,
      };

  /// For the agent editor: the tool's name for the user.
  static String title(String tool) => switch (tool) {
        webSearch => 'Search the web'.tr,
        readPage => 'Read a web page'.tr,
        searchDocuments => 'Search my documents'.tr,
        calculator => 'Calculator'.tr,
        dateTime => 'Date and time'.tr,
        remember => 'Remember facts about me'.tr,
        listFiles => 'See the files of its work folder'.tr,
        readFile => 'Read a file of its work folder'.tr,
        writeFile => 'Write a file in its work folder'.tr,
        runPython => 'Run Python code (computer)'.tr,
        askAssistant => 'Ask the other assistants'.tr,
        _ => tool,
      };

  final List<WebResult> webSources = [];
  final List<DocChunk> passages = [];

  /// Files written by the run, relative to the work folder.
  final List<String> filesWritten = [];

  final Future<List<WebResult>> Function(String query) searchWeb;
  final Future<String> Function(String url) fetchPage;
  final List<DocChunk> Function(String query) searchDocs;
  final DateTime Function() now;

  /// The agent's work folder (its file tools stay inside); null: no file
  /// tools.
  final Future<Directory> Function()? workspace;

  /// Asks the user before a tool writes, runs code or remembers; null:
  /// such tools are refused.
  final Future<bool> Function(AgentConfirmation request)? confirm;

  /// Runs another assistant on a task and returns its answer.
  final Future<String> Function(String assistant, String task)? delegate;

  /// The assistants [delegate] knows: name → what they do.
  final Map<String, String> assistants;

  /// Saves a fact to the memory.
  final Future<void> Function(String fact)? saveMemory;

  /// The Python program, when this computer has one.
  final String? python;
  final Duration pythonTimeout;

  /// Longest tool result given to the model, in characters: a phone's
  /// context is small.
  final int maxResultChars;

  AgentToolbox({
    required this.searchWeb,
    required this.fetchPage,
    required this.searchDocs,
    DateTime Function()? now,
    this.maxResultChars = 2000,
    this.workspace,
    this.confirm,
    this.delegate,
    this.assistants = const {},
    this.saveMemory,
    this.python,
    this.pythonTimeout = const Duration(seconds: 60),
  }) : now = now ?? DateTime.now;

  /// Whether [name] can work in this toolbox (its folder, program or
  /// helpers are there).
  bool isAvailable(String name) => switch (name) {
        listFiles || readFile || writeFile => workspace != null,
        runPython => python != null && workspace != null,
        askAssistant => delegate != null && assistants.isNotEmpty,
        remember => saveMemory != null,
        _ => true,
      };

  Future<bool> _ask(String tool, String title, String detail) async {
    final ask = confirm;
    if (ask == null) return false;
    return ask(AgentConfirmation(tool: tool, title: title, detail: detail));
  }

  String _cut(String text) => text.length <= maxResultChars
      ? text
      : '${text.substring(0, maxResultChars)}…';

  static String _arg(Map<String, dynamic> args, String key) =>
      '${args[key] ?? args.values.firstOrNull ?? ''}'.trim();

  /// The tools named in [names], in the usual order.
  List<AgentTool> tools(Iterable<String> names) => [
        for (final name in all)
          if (names.contains(name) && isAvailable(name)) _tool(name),
      ];

  AgentTool _tool(String name) => switch (name) {
        webSearch => AgentTool(
            name: webSearch,
            description:
                'Searches the web. Use it for recent facts, prices, news, or anything you are unsure of.',
            parameters: {'query': 'the search, a few words'},
            label: (a) =>
                'Searching the web: “@query”'.trParams({'query': _arg(a, 'query')}),
            run: (a) async {
              final query = _arg(a, 'query');
              if (query.isEmpty) throw const FormatException('No query');
              final results = await searchWeb(query);
              if (results.isEmpty) return 'No results.';
              // Numbered after the ones already found, so citations stay
              // unique over the whole run.
              final first = webSources.length;
              webSources.addAll(results);
              return _cut([
                for (var i = 0; i < results.length; i++)
                  '[${first + i + 1}] ${results[i].title}\n${results[i].url}\n${results[i].snippet}',
              ].join('\n\n'));
            },
          ),
        readPage => AgentTool(
            name: readPage,
            description:
                'Reads the text of a web page, for details a search result only hints at.',
            parameters: {'url': 'the address, starting with https://'},
            label: (a) => 'Reading @site'.trParams(
                {'site': Uri.tryParse(_arg(a, 'url'))?.host ?? _arg(a, 'url')}),
            run: (a) async => _cut(await fetchPage(_arg(a, 'url'))),
          ),
        searchDocuments => AgentTool(
            name: searchDocuments,
            description:
                "Searches the user's own documents (their files) for passages about something.",
            parameters: {'query': 'what to look for, a few words'},
            label: (a) => 'Searching your documents: “@query”'
                .trParams({'query': _arg(a, 'query')}),
            run: (a) async {
              final found = searchDocs(_arg(a, 'query'));
              if (found.isEmpty) return 'Nothing found in the documents.';
              passages.addAll(found);
              return _cut(DocumentLibrary.asContext(found));
            },
          ),
        calculator => AgentTool(
            name: calculator,
            description:
                'Computes arithmetic exactly. Always use it for calculations instead of doing them yourself.',
            parameters: {
              'expression': 'e.g. "(1250 * 0.2) + 35" (+ - * / % ^ sqrt round)'
            },
            label: (a) => 'Calculating @expression'
                .trParams({'expression': _arg(a, 'expression')}),
            run: (a) async {
              final expression = _arg(a, 'expression');
              return '$expression = ${Calculator.format(Calculator.evaluate(expression))}';
            },
          ),
        dateTime => AgentTool(
            name: dateTime,
            description: 'Gives the current date, time and day of the week.',
            parameters: const {},
            label: (_) => 'Checking the date'.tr,
            run: (_) async {
              final t = now();
              const days = [
                'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
                'Saturday', 'Sunday'
              ];
              String two(int n) => n.toString().padLeft(2, '0');
              return '${days[t.weekday - 1]} ${t.year}-${two(t.month)}-${two(t.day)} '
                  '${two(t.hour)}:${two(t.minute)}';
            },
          ),
        remember => AgentTool(
            name: remember,
            description:
                'Saves a lasting fact about the user (a preference, their situation) for future conversations. The user is asked first. Only for facts they would want remembered.',
            parameters: {'fact': 'the fact, one short sentence'},
            label: (a) => 'Remembering: “@fact”'.trParams({'fact': _arg(a, 'fact')}),
            run: (a) async {
              final fact = _arg(a, 'fact');
              if (fact.isEmpty) throw const FormatException('No fact');
              if (!await _ask(remember, 'Remember this?'.tr, fact)) {
                return 'The user declined: nothing was saved.';
              }
              await saveMemory!(fact);
              return 'Saved to memory.';
            },
          ),
        listFiles => AgentTool(
            name: listFiles,
            description:
                'Lists the files of the work folder (or of a sub-folder), with their sizes.',
            parameters: {'path': 'a sub-folder, or leave empty for the work folder'},
            optional: const {'path'},
            label: (a) => 'Looking at the files'.tr,
            run: (a) async {
              final dir = Directory(await _resolve('${a['path'] ?? ''}'));
              if (!await dir.exists()) return 'No such folder.';
              final root = (await workspace!()).path;
              final lines = <String>[];
              await for (final e in dir.list(followLinks: false)) {
                final rel = e.path.substring(root.length).replaceAll('\\', '/');
                final name = rel.startsWith('/') ? rel.substring(1) : rel;
                if (name.split('/').any((p) => p.startsWith('.privatelm'))) continue;
                if (e is Directory) {
                  lines.add('$name/');
                } else if (e is File) {
                  lines.add('$name (${_size(await e.length())})');
                }
                if (lines.length >= 200) break;
              }
              lines.sort();
              return lines.isEmpty ? 'The folder is empty.' : _cut(lines.join('\n'));
            },
          ),
        readFile => AgentTool(
            name: readFile,
            description:
                'Reads a file of the work folder: text, code, CSV, JSON, Markdown, PDF or Word.',
            parameters: {'path': 'the file, relative to the work folder'},
            label: (a) => 'Reading @file'.trParams({'file': _arg(a, 'path')}),
            run: (a) async {
              final file = File(await _resolve(_arg(a, 'path')));
              if (!await file.exists()) return 'No such file.';
              final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : '';
              if (const ['pdf', 'docx', 'xlsx', 'pptx', 'odt'].contains(ext)) {
                return _cut(await DocumentExtractorService.extractText(file.path, ext));
              }
              if (await file.length() > 2 * 1024 * 1024) {
                return 'The file is too big to read (over 2 MB).';
              }
              return _cut(utf8.decode(await file.readAsBytes(), allowMalformed: true));
            },
          ),
        writeFile => AgentTool(
            name: writeFile,
            description:
                'Writes a text file (Markdown, CSV, code…) in the work folder, replacing it if it exists. The user is asked first.',
            parameters: {
              'path': 'the file, relative to the work folder, e.g. "notes/plan.md"',
              'content': 'the whole text of the file',
            },
            label: (a) => 'Writing @file'.trParams({'file': _arg(a, 'path')}),
            run: (a) async {
              final rel = _arg(a, 'path');
              final content = '${a['content'] ?? ''}';
              final path = await _resolve(rel);
              final exists = await File(path).exists();
              final ok = await _ask(
                writeFile,
                exists
                    ? 'Replace @file?'.trParams({'file': rel})
                    : 'Write @file?'.trParams({'file': rel}),
                content.length > 4000 ? '${content.substring(0, 4000)}\n…' : content,
              );
              if (!ok) return 'The user declined: the file was not written.';
              final file = File(path);
              await file.parent.create(recursive: true);
              await file.writeAsString(content);
              filesWritten.add(rel);
              return 'Wrote ${content.length} characters to $rel.';
            },
          ),
        runPython => AgentTool(
            name: runPython,
            description:
                'Runs a Python 3 program on this computer, in the work folder, and returns what it prints (standard library only). Use it for exact computations, data analysis, or to check work. The user is asked first.',
            parameters: {'code': 'the whole Python program; print() what you need'},
            label: (a) => 'Running Python'.tr,
            run: (a) async {
              final code = '${a['code'] ?? ''}';
              if (code.trim().isEmpty) throw const FormatException('No code');
              if (!await _ask(runPython, 'Run this Python code?'.tr, code)) {
                return 'The user declined: the code was not run.';
              }
              return _cut(await _runPythonCode(code));
            },
          ),
        askAssistant => AgentTool(
            name: askAssistant,
            description:
                'Gives a task to another assistant and returns its answer. Write the task so it can be done without the conversation. Assistants: ${assistants.entries.map((e) => '${e.key} (${e.value})').join('; ')}.',
            parameters: {
              'assistant': 'the assistant\'s name, exactly as listed',
              'task': 'what it must do, with all the details it needs',
            },
            label: (a) => 'Asking @name'.trParams({'name': _assistantName(a)}),
            run: (a) async {
              final match = _knownAssistant(a);
              if (match == null) {
                return 'Unknown assistant. Choose one of: ${assistants.keys.join(', ')}.';
              }
              return _cut(await delegate!(match, '${a['task'] ?? ''}'));
            },
          ),
        _ => throw ArgumentError('Unknown tool $name'),
      };

  /// The assistant [args] name, as listed (the model may change its case).
  String? _knownAssistant(Map<String, dynamic> args) {
    final name = _arg(args, 'assistant').toLowerCase();
    return assistants.keys.where((k) => k.toLowerCase() == name).firstOrNull;
  }

  String _assistantName(Map<String, dynamic> args) =>
      _knownAssistant(args) ?? _arg(args, 'assistant');

  static String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  /// [input] as a path inside the work folder. Throws for a path that would
  /// leave it (absolute, "..", or a link pointing out).
  Future<String> _resolve(String input) async {
    final rel = safeRelative(input);
    if (rel == null) {
      throw const FormatException(
          'Only paths inside the work folder are allowed, like "notes/plan.md"');
    }
    final root = await workspace!();
    await root.create(recursive: true);
    final path = rel.isEmpty ? root.path : '${root.path}/$rel';
    // A link inside the folder must not lead outside it.
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      final real = await Link(path).resolveSymbolicLinks();
      final rootReal = await root.resolveSymbolicLinks();
      if (!real.startsWith(rootReal)) {
        throw const FormatException('This link leads outside the work folder');
      }
    }
    return path;
  }

  /// A path the model wrote, made relative and checked: null when it is
  /// absolute or climbs out with "..".
  static String? safeRelative(String input) {
    final p = input.trim().replaceAll('\\', '/');
    if (p.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(p) || p.startsWith('~')) {
      return null;
    }
    final parts = <String>[];
    for (final seg in p.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') return null;
      parts.add(seg);
    }
    return parts.join('/');
  }

  Future<String> _runPythonCode(String code) async {
    final root = await workspace!();
    await root.create(recursive: true);
    final dir = await Directory.systemTemp.createTemp('privatelm_py');
    final script = File('${dir.path}/agent.py');
    await script.writeAsString(code);
    try {
      final process = await Process.start(python!, ['-I', script.path],
          workingDirectory: root.path);
      final out = StringBuffer();
      final err = StringBuffer();
      final outDone = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(out.write);
      final errDone = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(err.write);
      int code;
      try {
        code = await process.exitCode.timeout(pythonTimeout);
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        return 'Stopped: the program ran longer than ${pythonTimeout.inSeconds} s.\n$out';
      }
      await Future.wait([outDone, errDone]);
      final parts = [
        if (out.isNotEmpty) out.toString().trimRight(),
        if (err.isNotEmpty) 'Errors:\n${err.toString().trimRight()}',
      ];
      return '${code == 0 ? 'Finished.' : 'Exit code $code.'}\n${parts.isEmpty ? '(nothing printed)' : parts.join('\n')}';
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// The Python 3 program of this computer, or null.
  static Future<String?> findPython() async {
    for (final candidate in Platform.isWindows
        ? const ['python', 'py', 'python3']
        : const ['python3', 'python']) {
      try {
        final r = await Process.run(candidate, ['--version'])
            .timeout(const Duration(seconds: 5));
        if (r.exitCode == 0 && '${r.stdout}${r.stderr}'.contains('Python 3')) {
          return candidate;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Reads a web page as plain text. Addresses of the local network are
  /// refused: a page read by the agent must not lead it to the user's own
  /// devices.
  static Future<String> readWebPage(String url, {http.Client? client}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Not a web address');
    }
    if (LanServerFinder.isLocal(uri.toString())) {
      throw const FormatException('Addresses of the local network are not read');
    }
    final c = client ?? http.Client();
    try {
      final response = await c.get(uri, headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept': 'text/html,text/plain;q=0.9,*/*;q=0.5',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        throw HttpExceptionText('The page answered ${response.statusCode}');
      }
      final type = response.headers['content-type'] ?? '';
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (!type.contains('html')) return body;
      return pageText(body);
    } finally {
      if (client == null) c.close();
    }
  }

  /// The readable text of an HTML page: its title, then its text without
  /// scripts, styles, menus or footers.
  static String pageText(String html) {
    final title = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
            .firstMatch(html)?[1] ??
        '';
    var text = html
        .replaceAll(
            RegExp(r'<(head|title|script|style|noscript|svg|nav|header|footer|form|aside)\b[\s\S]*?</\1>',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
        .replaceAll(
            RegExp(r'<(br|p|div|li|h[1-6]|tr|section|article)\b[^>]*>',
                caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _entities(text)
        .replaceAll(RegExp(r'[ \t ]+'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
    final heading = _entities(title).replaceAll(RegExp(r'\s+'), ' ').trim();
    return heading.isEmpty ? text : '$heading\n\n$text';
  }

  static String _entities(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.tryParse(m[1]!) ?? 32));
}

/// A failure to show the model as text.
class HttpExceptionText implements Exception {
  final String message;
  const HttpExceptionText(this.message);
  @override
  String toString() => message;
}

/// An action a tool wants to take, for the user to allow or refuse.
class AgentConfirmation {
  /// The tool's name.
  final String tool;
  final String title;

  /// What exactly would happen: the code, the file's text, the fact.
  final String detail;

  const AgentConfirmation(
      {required this.tool, required this.title, required this.detail});
}
