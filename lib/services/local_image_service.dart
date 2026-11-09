/// Local image generation: stable-diffusion.cpp through FFI on phones and
/// desktops, the WebGPU engine on the web.
library;

export 'local_image_service_native.dart'
    if (dart.library.js_interop) 'local_image_service_web.dart';
