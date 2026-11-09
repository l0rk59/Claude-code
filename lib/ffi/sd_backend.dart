/// Image generation backends and settings. The FFI bindings on native
/// platforms; enums only on the web, which has no FFI.
library;

export 'sd_ffi_bindings.dart'
    if (dart.library.js_interop) 'sd_ffi_bindings_web.dart';
