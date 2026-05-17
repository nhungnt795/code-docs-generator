// lib/features/generate/presentation/download_helper_io.dart
//
// Mobile & desktop implementation. Imported conditionally via download_helper.dart.
// Saves the file to the Downloads folder on Android, or the system temp dir
// on other platforms. A production app should also open/share the file via
// the share_plus package, but saving is sufficient to make exports functional.

import 'dart:io';

void downloadBytes(List<int> bytes, String filename) async {
  try {
    final dir = await _resolveDownloadDir();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    // Optionally: show a snackbar / notification pointing to file.path
  } catch (_) {
    // Silently ignore – the caller should handle UI feedback if needed
  }
}

Future<Directory> _resolveDownloadDir() async {
  if (Platform.isAndroid) {
    final downloads = Directory('/storage/emulated/0/Download');
    if (await downloads.exists()) return downloads;
  }
  if (Platform.isIOS) {
    // On iOS use the app's Documents directory (accessible via Files app)
    final docs = Directory('${Platform.environment['HOME']}/Documents');
    if (await docs.exists()) return docs;
  }
  return Directory.systemTemp;
}
