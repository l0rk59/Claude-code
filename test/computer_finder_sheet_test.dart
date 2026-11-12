import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:privatelm/core/ui.dart';
import 'package:privatelm/services/lan_server_finder.dart';
import 'package:privatelm/views/computer_finder_sheet.dart';

void main() {
  const laptop = LanServer(
    host: '192.168.1.20',
    port: 8080,
    software: 'llama.cpp',
    models: ['Qwen3.5-35B-A3B-Q4_K_M.gguf'],
  );

  /// Opens the sheet over a page, the way the Models screen does.
  Future<void> open(WidgetTester tester, ComputerFinderSheet sheet) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showAppSheet<bool>(context, builder: (_) => sheet),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the computers found and connects to the model picked',
      (tester) async {
    final picked = <String>[];
    await open(
      tester,
      ComputerFinderSheet(
        scan: (onProgress, cancelled) async {
          onProgress(1);
          return [laptop];
        },
        onConnect: (server, model) async =>
            picked.add('${server.baseUrl} $model'),
      ),
    );
    expect(find.text('llama.cpp · 192.168.1.20:8080'), findsOneWidget);

    await tester.tap(find.text('Qwen3.5-35B-A3B-Q4_K_M.gguf'));
    await tester.pumpAndSettle();
    expect(picked, ['http://192.168.1.20:8080/v1 Qwen3.5-35B-A3B-Q4_K_M.gguf']);
    // The sheet closed.
    expect(find.text('llama.cpp · 192.168.1.20:8080'), findsNothing);
  });

  testWidgets('says what to do when nothing is found, and takes an address',
      (tester) async {
    final asked = <String>[];
    await open(
      tester,
      ComputerFinderSheet(
        scan: (onProgress, cancelled) async => const [],
        find: (input) async {
          asked.add(input);
          return input == '192.168.1.20' ? [laptop] : const [];
        },
        onConnect: (_, __) async {},
      ),
    );
    expect(find.textContaining('No computer found'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '192.168.1.99');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No model server answers there'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '192.168.1.20');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(asked, ['192.168.1.99', '192.168.1.20']);
    expect(find.text('llama.cpp · 192.168.1.20:8080'), findsOneWidget);
    expect(find.textContaining('No computer found'), findsNothing);
    expect(find.textContaining('No model server answers there'), findsNothing);
  });

  testWidgets('a computer with no model says so', (tester) async {
    await open(
      tester,
      ComputerFinderSheet(
        scan: (onProgress, cancelled) async =>
            const [LanServer(host: '192.168.1.30', port: 11434, software: 'Ollama')],
        onConnect: (_, __) async {},
      ),
    );
    expect(find.text('Ollama · 192.168.1.30:11434'), findsOneWidget);
    expect(find.text('This computer has no model ready yet.'), findsOneWidget);
  });
}
