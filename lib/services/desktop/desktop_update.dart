import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../core/ui.dart';
import '../hive_service.dart';
import '../update_service.dart';

/// A newer version for this computer.
class DesktopRelease {
  final String version;

  /// The file for this system, or the release page when there is none.
  final String url;
  final String fileName;
  const DesktopRelease(
      {required this.version, required this.url, this.fileName = ''});
}

/// The computer app's update check: GitHub's latest release, the file for
/// this system. Installing is left to the user (unzip over the old one).
class DesktopUpdateService extends GetxService {
  final http.Client Function() _client;
  DesktopUpdateService({http.Client Function()? client})
      : _client = client ?? http.Client.new;

  final currentVersion = ''.obs;
  final available = Rxn<DesktopRelease>();
  final checking = false.obs;

  /// The release file for [os] among a release's [assets] (GitHub's JSON).
  static Map<String, dynamic>? assetFor(List assets, String os) {
    final suffix = switch (os) {
      'windows' => '-windows-x64.zip',
      'macos' => '-macos.zip',
      _ => '-linux-x64.tar.gz',
    };
    for (final a in assets) {
      if (a is Map && '${a['name']}'.endsWith(suffix)) {
        return Map<String, dynamic>.from(a);
      }
    }
    return null;
  }

  /// [json] (GitHub's latest release) when newer than [current].
  static DesktopRelease? newerRelease(
      Map<String, dynamic> json, String current, String os) {
    var tag = '${json['tag_name'] ?? ''}'.trim();
    if (tag.startsWith('v') || tag.startsWith('V')) tag = tag.substring(1);
    if (tag.isEmpty || UpdateService.compareVersions(tag, current) <= 0) {
      return null;
    }
    final asset = assetFor(json['assets'] as List? ?? const [], os);
    return DesktopRelease(
      version: tag,
      url: '${asset?['browser_download_url'] ?? json['html_url'] ?? ''}',
      fileName: '${asset?['name'] ?? ''}',
    );
  }

  String get _os => Platform.isWindows
      ? 'windows'
      : Platform.isMacOS
          ? 'macos'
          : 'linux';

  @override
  void onInit() {
    super.onInit();
    // Once a day at most, a little after the start.
    Future<void>.delayed(const Duration(seconds: 8), () async {
      final hive = Get.isRegistered<HiveService>() ? Get.find<HiveService>() : null;
      final last = hive?.getSetting<int>(AppConstants.keyLastUpdateCheck) ?? 0;
      final since = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(last));
      if (since < const Duration(hours: 20)) return;
      final release = await check();
      if (release != null) {
        showToast(
          'PrivateLM @version is available'.trParams({'version': release.version}),
          'Settings > About to download it.'.tr,
          duration: const Duration(seconds: 6),
        );
      }
    });
  }

  /// Looks for a newer version. [manual]: says the result.
  Future<DesktopRelease?> check({bool manual = false}) async {
    if (checking.value) return available.value;
    checking.value = true;
    final client = _client();
    try {
      if (currentVersion.value.isEmpty) {
        currentVersion.value = (await PackageInfo.fromPlatform()).version;
      }
      final res = await client.get(
        Uri.parse(
            'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      if (Get.isRegistered<HiveService>()) {
        await Get.find<HiveService>().setSetting(
            AppConstants.keyLastUpdateCheck,
            DateTime.now().millisecondsSinceEpoch);
      }
      available.value = res.statusCode == 200
          ? newerRelease(jsonDecode(res.body) as Map<String, dynamic>,
              currentVersion.value, _os)
          : null;
      if (manual && available.value == null) {
        showToast("You're up to date".tr,
            'PrivateLM @version is the latest version.'
                .trParams({'version': currentVersion.value}),
            tone: ToastTone.success);
      }
      return available.value;
    } catch (_) {
      if (manual) {
        showToast("Couldn't check for updates".tr,
            'Check your connection and try again.'.tr,
            tone: ToastTone.error);
      }
      return null;
    } finally {
      client.close();
      checking.value = false;
    }
  }

  /// Opens [url] in the browser.
  static Future<void> openInBrowser(String url) async {
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  }
}
