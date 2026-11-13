import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/services/hive_service.dart';
import 'package:privatelm/services/memory_service.dart';
import 'package:privatelm/services/task_templates.dart';

void main() {
  late Directory dir;
  late HiveService hive;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('memory');
    Hive.init(dir.path);
    hive = await HiveService().init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('hears when it is asked to remember something', () {
    expect(Memories.requested('Souviens-toi que je suis végétarien.'),
        'je suis végétarien');
    expect(Memories.requested("retiens que mon fils s'appelle Léo"),
        "mon fils s'appelle Léo");
    expect(Memories.requested("N'oublie pas : je travaille de nuit"),
        'je travaille de nuit');
    expect(Memories.requested('Rappelle-toi de me tutoyer'), 'me tutoyer');
    expect(Memories.requested('Remember that I live in Lille'), 'I live in Lille');
    expect(Memories.requested('please remember: no peanuts'), 'no peanuts');
    expect(Memories.requested('Quel temps fait-il à Lille ?'), isNull);
    expect(Memories.requested('Je me souviens de ce film'), isNull);
    expect(Memories.requested('retiens'), isNull);
  });

  test('keeps each fact once, the newest when there are too many', () async {
    await Memories.add(hive, 'je suis végétarien');
    await Memories.add(hive, 'Je suis végétarien.');
    expect(Memories.all(hive), ['je suis végétarien']);

    for (var i = 0; i < Memories.maxFacts + 5; i++) {
      await Memories.add(hive, 'fait $i');
    }
    final kept = Memories.all(hive);
    expect(kept, hasLength(Memories.maxFacts));
    expect(kept.last, 'fait ${Memories.maxFacts + 4}');

    await Memories.remove(hive, kept.last);
    expect(Memories.all(hive), isNot(contains(kept.last)));
    await Memories.clear(hive);
    expect(Memories.all(hive), isEmpty);
  });

  test('tells the model what it knows, only when it knows something', () {
    expect(Memories.forSystemPrompt(const [], 'About the user:'), '');
    expect(
        Memories.forSystemPrompt(
            const ['je suis végétarien', 'vit à Lille'], 'About the user:'),
        'About the user:\n- je suis végétarien\n- vit à Lille');
  });

  test("the user's tasks are kept, replaced by name and deleted", () async {
    expect(TaskTemplates.builtIn(), hasLength(10));
    expect(TaskTemplates.builtIn().first.prompt, endsWith('\n\n'));

    await TaskTemplates.save(hive, 'Compte rendu', 'Fais un compte rendu de :');
    await TaskTemplates.save(hive, 'Compte rendu', 'Fais un compte rendu court de :');
    await TaskTemplates.save(hive, '  ', 'ignored');
    final mine = TaskTemplates.custom(hive);
    expect(mine.single.prompt, 'Fais un compte rendu court de :');
    expect(mine.single.custom, isTrue);

    await TaskTemplates.delete(hive, 'Compte rendu');
    expect(TaskTemplates.custom(hive), isEmpty);
  });
}
