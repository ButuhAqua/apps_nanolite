import 'package:url_launcher/url_launcher.dart';

Future<void> downloadFile(String? url, {String? fileName}) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  // Non-web: buka via app/browser (biasanya auto-download kalau header server attachment)
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
