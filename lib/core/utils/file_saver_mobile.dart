import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> saveFile(List<int> bytes, String fileName, String mimeType) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        dir = downloadDir;
      } else {
        dir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();

    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // Redirect & Open the PDF/file on mobile device
    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
  } catch (e) {
    print('Error saving/opening file on mobile: $e');
  }
}
