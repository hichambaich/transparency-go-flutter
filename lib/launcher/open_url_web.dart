// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: calls window.open() directly — identical to Flet's page.launch_url.
/// Called synchronously inside the user gesture, so popup blockers do not interfere.
Future<bool> openUrl(String url) async {
  try {
    html.window.open(url, '_blank');
    return true;
  } catch (e) {
    print('openUrl (web) error: $e');
    return false;
  }
}
