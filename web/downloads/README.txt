Place your production APK file here.

File should be named: app-arm64-v8a-release.apk
(or update apk_config.json to point to the correct filename)

To add the APK:
1. Build: flutter build apk --split-per-abi
2. Copy: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk → web/downloads/
3. Update version in web/apk_config.json
4. Deploy: firebase deploy --only hosting
