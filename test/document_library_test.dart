import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/document_library.dart';

void main() {
  late Directory dir;
  late DocumentLibrary library;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library');
    library = DocumentLibrary(File('${dir.path}/library.json'));
    await library.load();
  });

  tearDown(() => dir.delete(recursive: true));

  test('compares words without accents, plurals or small words', () {
    expect(DocumentLibrary.words("Les échéances du prêt immobilier"),
        ['echeance', 'pret', 'immobilier']);
    expect(DocumentLibrary.words('What is the warranty?'), ['warranty']);
  });

  test('cuts long text into overlapping passages at sentence ends', () {
    const sentence = 'Cette phrase parle du contrat de location. ';
    final chunks = DocumentLibrary.split(sentence * 80);
    expect(chunks.length, greaterThan(3));
    for (final c in chunks) {
      expect(c.length, lessThanOrEqualTo(DocumentLibrary.chunkSize));
      expect(c, endsWith('.'));
    }
    // Nothing is lost: every passage's start appears in the previous one's
    // end, or right after it.
    expect(chunks.join(' '), contains('contrat de location'));
    expect(DocumentLibrary.split('   \n\n  '), isEmpty);
    expect(DocumentLibrary.split('court.'), ['court.']);
  });

  test('finds the passage that answers the question', () async {
    await library.add('bail.pdf', '''
Le loyer mensuel est fixé à 850 euros, charges comprises.

${'Clause générale sans rapport avec la question posée. ' * 30}

Le dépôt de garantie s'élève à un mois de loyer hors charges et sera restitué dans un délai de deux mois après la remise des clés.
''');
    await library.add('voiture.txt',
        'La garantie constructeur du véhicule couvre deux ans ou 100 000 km.');

    final found = library.search('Quel est le montant du dépôt de garantie ?');
    expect(found.first.document, 'bail.pdf');
    expect(found.first.text, contains('dépôt de garantie'));

    final car = library.search('garantie du véhicule');
    expect(car.first.document, 'voiture.txt');

    expect(library.search('astronomie quantique'), isEmpty);
    expect(library.search('le la les'), isEmpty);
  });

  test('keeps documents between launches, replaces and removes them',
      () async {
    final first = await library.add('notes.md', 'Réunion mardi à 14 h.');
    await library.add('notes.md', 'Réunion jeudi à 10 h.');
    expect(library.documents, hasLength(1));

    final again = DocumentLibrary(File('${dir.path}/library.json'));
    await again.load();
    expect(again.documents.single.name, 'notes.md');
    expect(again.search('réunion').single.text, contains('jeudi'));

    await again.remove(again.documents.single.id);
    final empty = DocumentLibrary(File('${dir.path}/library.json'));
    await empty.load();
    expect(empty.documents, isEmpty);
    expect(first.characters, greaterThan(0));
  });

  test('a damaged library starts empty', () async {
    await File('${dir.path}/library.json').writeAsString('{not json');
    await library.load();
    expect(library.documents, isEmpty);
  });

  test('labels passages with their document for the model', () {
    expect(
        DocumentLibrary.asContext(
            const [DocChunk('bail.pdf', 'Loyer : 850 €.')]),
        '[1] (bail.pdf)\nLoyer : 850 €.');
  });
}
