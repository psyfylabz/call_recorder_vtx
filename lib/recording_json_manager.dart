import 'dart:io';
import 'dart:convert';

class RecordingJsonManager {
  static const String dataDir = "/storage/emulated/0/Recordings/VTX Files/Data";

  static File _fileForId(String id) {
    return File("$dataDir/$id.json");
  }

  /// Kreiramo json na START
  static Future<void> createOnStart({
    required String id,
    required String title,
    required String date,
    required String path,
  }) async {
    final file = _fileForId(id);
    final json = {
      "id": id,
      "title": title,
      "date": date,
      "path": path,
      "status": "processing",
      "pinned": false,
      "notes": null,
      "highlighted": {"offset": 0, "length": 0}
    };
    await file.writeAsString(jsonEncode(json));
  }

  /// Ažuriranje offset-a tokom snimanja
  static Future<void> updateOnHighlight(String id, int offset) async {
    final file = _fileForId(id);
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      data["highlighted"]["offset"] = offset;
      await file.writeAsString(jsonEncode(data));
    }
  }

  /// Ažuriranje dužine kada se STOP desi
  static Future<void> finalizeOnStop(String id, int length) async {
    final file = _fileForId(id);
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      data["highlighted"]["length"] = length;
      await file.writeAsString(jsonEncode(data));
    }
  }
}
