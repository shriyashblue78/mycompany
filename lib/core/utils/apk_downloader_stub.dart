// APK Download Utility — stub for non-web platforms
// On Android/iOS, users already have the native app installed.
// These functions are no-ops on non-web.

Future<Map<String, dynamic>> fetchApkConfig() async {
  return {'version': '1.0.0', 'apk_url': '', 'apk_filename': 'MyCompanyERP.apk'};
}

Future<void> downloadApk() async {
  // No-op on non-web platforms
}

bool isAndroidBrowser() => false;
bool isMobileBrowser() => false;
