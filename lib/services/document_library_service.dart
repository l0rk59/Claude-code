import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'document_extractor_service.dart';
import 'document_library.dart';

/// The app's [DocumentLibrary], kept in the app's private storage.
class DocumentLibraryService extends GetxService {
  late final DocumentLibrary library;

  /// The documents, for the screens to follow.
  final documents = <LibraryDocument>[].obs;

  Future<DocumentLibraryService> init() async {
    final dir = await getApplicationDocumentsDirectory();
    library = DocumentLibrary(File('${dir.path}/documents/library.json'));
    await library.load();
    documents.assignAll(library.documents);
    return this;
  }

  /// Reads the file at [path] and adds its text. Returns the document, or
  /// throws with a message when the file has no readable text.
  Future<LibraryDocument> addFile(String path, String name) async {
    final extension = name.contains('.') ? name.split('.').last : '';
    final text = await DocumentExtractorService.extractText(path, extension);
    if (text.trim().length < 20) {
      throw Exception("No text could be read from this file.".tr);
    }
    final document = await library.add(name, text);
    documents.assignAll(library.documents);
    return document;
  }

  Future<void> remove(String id) async {
    await library.remove(id);
    documents.assignAll(library.documents);
  }
}
