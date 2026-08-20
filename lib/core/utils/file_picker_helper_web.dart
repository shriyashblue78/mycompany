import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'file_picker_helper.dart';

Future<PickedFileResult?> pickFileImpl() async {
  final completer = Completer<PickedFileResult?>();
  final uploadInput = html.InputElement(type: 'file');
  uploadInput.accept = '.pdf,.png,.jpg,.jpeg';
  uploadInput.style.display = 'none';
  html.document.body?.append(uploadInput);

  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        final bytes = reader.result as Uint8List;
        final name = file.name;
        final dotIndex = name.lastIndexOf('.');
        final ext = dotIndex != -1 ? name.substring(dotIndex + 1).toLowerCase() : '';
        
        completer.complete(PickedFileResult(
          name: name,
          extension: ext,
          size: file.size ?? bytes.length,
          bytes: bytes,
        ));
        uploadInput.remove();
      });
    } else {
      completer.complete(null);
      uploadInput.remove();
    }
  });

  // Fallback in case user cancels file selection dialog
  late StreamSubscription focusSub;
  focusSub = html.window.onFocus.listen((event) {
    focusSub.cancel();
    Future.delayed(const Duration(seconds: 1), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        uploadInput.remove();
      }
    });
  });

  return completer.future;
}
