import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_platform.dart';

/// Where the app keeps its files.
abstract final class AppDirs {
  /// A folder the user chose for the models (computer app only); null for
  /// the default one inside [data].
  static String? modelsOverride;

  /// The app's own folder: the documents folder on a phone (where earlier
  /// versions already keep their files), the application data folder on a
  /// computer (so the user's Documents stay clean).
  static Future<Directory> data() async {
    final dir = AppPlatform.isDesktop
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The folder holding the models.
  static Future<String> models() async {
    final custom = modelsOverride;
    final path = custom != null && custom.isNotEmpty
        ? custom
        : '${(await data()).path}/models';
    await Directory(path).create(recursive: true);
    return path;
  }
}

/// The last part of a file path, whichever separator it uses (Windows
/// paths use backslashes).
String baseName(String path) {
  final i = path.lastIndexOf(RegExp(r'[/\\]'));
  return i < 0 ? path : path.substring(i + 1);
}

/// The folder part of a file path ('' when there is none).
String dirName(String path) {
  final i = path.lastIndexOf(RegExp(r'[/\\]'));
  return i < 0 ? '' : path.substring(0, i);
}
