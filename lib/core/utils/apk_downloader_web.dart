// APK Download Utility — web implementation
// Uses dart:html to trigger a direct download of the hosted APK.
// The APK URL is read from /apk_config.json so it can be updated
// without code changes.

// ignore: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

/// Fetches the APK config from /apk_config.json and returns it.
Future<Map<String, dynamic>> fetchApkConfig() async {
  try {
    final xhr = html.HttpRequest();
    xhr.open('GET', '/apk_config.json');
    await xhr.onLoadEnd.first;
    if (xhr.status == 200) {
      return json.decode(xhr.responseText ?? '{}') as Map<String, dynamic>;
    }
  } catch (_) {}
  // Fallback defaults
  return {
    'version': '1.0.0',
    'apk_url': '/downloads/app-release.apk',
    'apk_filename': 'MyCompanyERP-Universal.apk',
  };
}

/// Triggers a direct browser download of the production APK.
/// The APK must be hosted at the URL specified in /apk_config.json.
Future<void> downloadApk() async {
  final config = await fetchApkConfig();
  final url = config['apk_url'] as String? ?? '/downloads/app-release.apk';
  final filename = config['apk_filename'] as String? ?? 'MyCompanyERP-Universal.apk';

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

/// Returns true if the browser is running on Android.
bool isAndroidBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('android');
}

/// Returns true if the browser is on a mobile device (Android or iOS).
bool isMobileBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('android') || ua.contains('iphone') || ua.contains('ipad') || ua.contains('mobile');
}
