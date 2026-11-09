/// The Android ABI this app runs as ("arm64-v8a", ...), used to pick the
/// matching APK. Uses dart:ffi, so the web build gets a stub.
library;

export 'android_abi_io.dart'
    if (dart.library.js_interop) 'android_abi_web.dart';
