// lib/utils/downloader.dart
// Facade: ekspor fungsi yang otomatis memilih implementasi sesuai platform.
import 'downloader_io.dart'
  if (dart.library.html) 'downloader_web.dart' as impl;

/// Panggil dari UI: satu API untuk semua platform.
Future<void> downloadFile(String url, {required String fileName}) {
  return impl.downloadFile(url, fileName: fileName);
}
