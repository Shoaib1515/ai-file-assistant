import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

abstract class FileSaver {
  static Future<String> saveFile(String fileName, List<int> bytes) =>
      saveFileImpl(fileName, bytes);
}
