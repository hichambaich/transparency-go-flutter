import 'package:url_launcher/url_launcher.dart';

/// Mobile/Desktop implementation: delegates to url_launcher.
Future<bool> openUrl(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    print('openUrl (io) error: $e');
    return false;
  }
}
