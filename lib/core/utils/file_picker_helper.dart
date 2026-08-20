import 'file_picker_helper_stub.dart'
    if (dart.library.html) 'file_picker_helper_web.dart' as impl;
import 'dart:typed_data';

class PickedFileResult {
  final String name;
  final String extension;
  final int size;
  final Uint8List bytes;

  PickedFileResult({
    required this.name,
    required this.extension,
    required this.size,
    required this.bytes,
  });
}

class FilePickerHelper {
  static Future<PickedFileResult?> pickFile() {
    return impl.pickFileImpl();
  }
}
