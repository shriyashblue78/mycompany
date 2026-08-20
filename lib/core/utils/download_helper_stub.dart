import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFile(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);
      await Gal.putImage(tempFile.path);
      await tempFile.delete();
    } else {
      throw Exception('Failed to download image: Status code ${response.statusCode}');
    }
  } catch (e) {
    rethrow;
  }
}
