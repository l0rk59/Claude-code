import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Crash reports stay on the device: errors go to the app's log
/// (Settings > Logs), nothing is sent anywhere. The class keeps the
/// reporting entry points so a reporting service could be plugged in
/// later without touching the callers.
class CrashReportingService extends GetxService {
  bool get isEnabled => false;

  Future<CrashReportingService> init() async => this;

  Future<void> recordFlutterFatal(FlutterErrorDetails details) async {}

  Future<void> recordFatal(Object error, StackTrace stack,
      {String reason = 'fatal'}) async {}

  Future<void> recordNonFatal(
    Object error, {
    StackTrace? stack,
    String reason = 'nonfatal',
    Map<String, Object?> extra = const {},
  }) async {}

  void log(String message) {}

  Future<void> updateContext({
    String reason = 'context',
    Map<String, Object?> extra = const {},
  }) async {}
}
