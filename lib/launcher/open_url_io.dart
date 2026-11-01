import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

/// Mobile/Desktop implementation: delegates to url_launcher.
Future<bool> openUrl(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('openUrl (io) error: $e');
    return false;
  }
}
