import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/desktop/desktop_update.dart';

void main() {
  final release = {
    'tag_name': 'v1.2.0',
    'html_url': 'https://github.com/l0rk59/Claude-code/releases/tag/v1.2.0',
    'assets': [
      {'name': 'PrivateLM-1.2.0-arm64-v8a.apk', 'browser_download_url': 'https://x/apk'},
      {'name': 'PrivateLM-1.2.0-windows-x64.zip', 'browser_download_url': 'https://x/win'},
      {'name': 'PrivateLM-1.2.0-linux-x64.tar.gz', 'browser_download_url': 'https://x/linux'},
      {'name': 'PrivateLM-1.2.0-macos.zip', 'browser_download_url': 'https://x/mac'},
    ],
  };

  test('offers the file for this system when the release is newer', () {
    final win = DesktopUpdateService.newerRelease(release, '1.1.0', 'windows')!;
    expect(win.version, '1.2.0');
    expect(win.url, 'https://x/win');
    expect(win.fileName, 'PrivateLM-1.2.0-windows-x64.zip');
    expect(DesktopUpdateService.newerRelease(release, '1.1.0', 'linux')!.url,
        'https://x/linux');
    expect(DesktopUpdateService.newerRelease(release, '1.1.9', 'macos')!.url,
        'https://x/mac');
  });

  test('nothing when it is the same or older', () {
    expect(DesktopUpdateService.newerRelease(release, '1.2.0', 'windows'), isNull);
    expect(DesktopUpdateService.newerRelease(release, '1.10.0', 'linux'), isNull);
    expect(DesktopUpdateService.newerRelease({'tag_name': ''}, '1.0.0', 'linux'), isNull);
  });

  test('the release page when it has no file for this system', () {
    final r = DesktopUpdateService.newerRelease(
        {...release, 'assets': const []}, '1.0.0', 'windows')!;
    expect(r.url, release['html_url']);
    expect(r.fileName, '');
  });
}
