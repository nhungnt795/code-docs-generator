// lib/features/generate/presentation/download_helper_io.dart
//
// Mobile & desktop native implementation.
// ─────────────────────────────────────────────────────────────
// Android : lưu vào /storage/emulated/0/Download rồi scan MediaStore
// iOS     : ghi vào thư mục tạm rồi mở Share Sheet
// Desktop : ghi vào systemTemp
// ─────────────────────────────────────────────────────────────
// pubspec.yaml cần:
//   share_plus: ^10.0.0
//   path_provider: ^2.1.0

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void downloadBytes(List<int> bytes, String filename) async {
  try {
    if (Platform.isIOS) {
      // iOS: ghi ra temp rồi mở Share Sheet → user chọn "Save to Files"
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, name: filename)],
        subject: filename,
      );
    } else if (Platform.isAndroid) {
      // Android: lưu thẳng vào Downloads
      final dir = Directory('/storage/emulated/0/Download');
      final saveDir = (await dir.exists()) ? dir : await getTemporaryDirectory();
      final file = File('${saveDir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      // Quét MediaStore để file hiện ngay trong Files/Downloads
      try {
        await Process.run('am', [
          'broadcast',
          '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d', 'file://${file.path}',
        ]);
      } catch (_) {}
    } else {
      // Desktop / other
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
    }
  } catch (_) {
    // Caller handles UI feedback via DgToast
  }
}