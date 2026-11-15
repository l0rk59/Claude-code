import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform checks that also work on the web, where dart:io's [Platform]
/// throws. Always false in a browser, whatever device it runs on.
abstract final class AppPlatform {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// A phone or a tablet app (not the web).
  static bool get isMobile => isAndroid || isIOS;

  /// The computer app: Windows, Linux or macOS.
  static bool get isDesktop => isWindows || isLinux || isMacOS;
}
