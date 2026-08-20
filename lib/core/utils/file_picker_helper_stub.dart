import 'package:file_picker/file_picker.dart';
import 'file_picker_helper.dart';

Future<PickedFileResult?> pickFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    withData: true,
  );
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    if (file.bytes != null) {
      return PickedFileResult(
        name: file.name,
        extension: file.extension?.toLowerCase() ?? '',
        size: file.size,
        bytes: file.bytes!,
      );
    }
  }
  return null;
}
