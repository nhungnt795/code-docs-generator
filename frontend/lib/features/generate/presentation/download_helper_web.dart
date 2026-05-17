// lib/features/generate/presentation/download_helper_web.dart
//
// Web-only implementation. Imported conditionally via download_helper.dart.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBytes(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
