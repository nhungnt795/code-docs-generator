// lib/features/generate/presentation/download_helper.dart
//
// Conditional import: picks the right implementation at compile time.
//   dart.library.html  → web (browser)
//   dart.library.io    → mobile / desktop
//   fallback           → stub (analyzer / unsupported)

export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_io.dart';
