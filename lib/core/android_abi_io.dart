import 'dart:ffi' show Abi;

/// APK split name for this process's ABI, or 'universal'.
String androidAbiTag() => switch (Abi.current()) {
      Abi.androidArm64 => 'arm64-v8a',
      Abi.androidArm => 'armeabi-v7a',
      Abi.androidX64 => 'x86_64',
      _ => 'universal',
    };
