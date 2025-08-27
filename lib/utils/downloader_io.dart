// lib/utils/downloader_io.dart
import 'package:url_launcher/url_launcher.dart';

/// Implementasi Android/iOS/Desktop:
/// Serahkan ke sistem (viewer/Downloads app)
Future<void> downloadFile(String url, {required String fileName}) async {
  if (url.isEmpty) return;
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
