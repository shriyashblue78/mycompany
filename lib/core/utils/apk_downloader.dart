// APK Downloader — conditional export
// Uses the web implementation on Flutter Web, stub elsewhere.
export 'apk_downloader_stub.dart'
    if (dart.library.html) 'apk_downloader_web.dart';
