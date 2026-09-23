import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> saveFile(List<int> bytes, String fileName, String mimeType) async {
  try {
    File? savedFile;
    if (Platform.isAndroid) {
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final testFile = File('${downloadDir.path}/$fileName');
          await testFile.writeAsBytes(bytes, flush: true);
          savedFile = testFile;
        }
      } catch (_) {
        // Fall back if permission denied for public download folder
      }
    }

    if (savedFile == null) {
      final docsDir = await getApplicationDocumentsDirectory();
      final localFile = File('${docsDir.path}/$fileName');
      await localFile.writeAsBytes(bytes, flush: true);
      savedFile = localFile;
    }

    final uri = Uri.file(savedFile.path);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (!launched) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  } catch (e) {
    rethrow;
  }
}
