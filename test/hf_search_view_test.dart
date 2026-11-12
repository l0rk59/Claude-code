import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privatelm/services/hf_search_service.dart';
import 'package:privatelm/views/hf_search_view.dart';

void main() {
  Future<void> open(WidgetTester tester, MockClient client) async {
    await tester.pumpWidget(GetMaterialApp(
      home: HfSearchView(service: HfSearchService(client: client)),
    ));
  }

  /// Types [text] and waits past the search delay.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets('shows ideas, then the repositories found', (tester) async {
    final asked = <String>[];
    await open(
      tester,
      MockClient((request) async {
        asked.add(request.url.queryParameters['search'] ?? '');
        return http.Response(
            jsonEncode([
              {
                'id': 'unsloth/Qwen3.5-2B-GGUF',
                'downloads': 504854,
                'likes': 176
              },
              {'id': 'bartowski/Qwen3.5-2B-GGUF', 'downloads': 1200},
            ]),
            200);
      }),
    );
    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('Gemma 4'), findsOneWidget);

    await type(tester, 'qwen3.5 2b');
    expect(asked, ['qwen3.5 2b']);
    expect(find.text('Qwen3.5-2B'), findsNWidgets(2));
    expect(find.text('unsloth'), findsOneWidget);
    expect(find.text('505K'), findsOneWidget);
    expect(find.text('Ideas'), findsNothing);

    // Clearing the field brings the ideas back.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(find.text('Ideas'), findsOneWidget);
  });

  testWidgets('an idea starts a search', (tester) async {
    final asked = <String>[];
    await open(
      tester,
      MockClient((request) async {
        asked.add(request.url.queryParameters['search'] ?? '');
        return http.Response('[]', 200);
      }),
    );
    await tester.tap(find.text('Gemma 4'));
    await tester.pump();
    await tester.pump();
    expect(asked, ['Gemma 4']);
    expect(find.text('No model found'), findsOneWidget);
  });

  testWidgets('says when Hugging Face is unreachable, and retries',
      (tester) async {
    var calls = 0;
    await open(
      tester,
      MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('down', 503)
            : http.Response(
                jsonEncode([
                  {'id': 'a/Tiny-GGUF'}
                ]),
                200);
      }),
    );
    await type(tester, 'tiny');
    expect(find.text("Couldn't reach Hugging Face"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Tiny'), findsOneWidget);
  });
}
