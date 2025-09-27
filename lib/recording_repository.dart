import 'dart:convert';
import 'dart:io';
import 'recording.dart';

class RecordingRepository {
  final String dataDir =
      "/storage/emulated/0/Recordings/VTX Files/Data"; // folder gde su json fajlovi

  Future<List<Recording>> loadAll() async {
    final dir = Directory(dataDir);
    if (!await dir.exists()) {
      return [];
    }

    final files = dir
        .listSync()
        .where((f) => f is File && f.path.endsWith(".json"))
        .map((f) => File(f.path));

    final recordings = <Recording>[];

    for (var file in files) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        recordings.add(Recording.fromJson(data));
      } catch (e) {
        print("❌ Failed to parse ${file.path}: $e");
      }
    }

    // sort by date + time (koristimo highlightStart)
    recordings.sort((a, b) => b.highlightStart.compareTo(a.highlightStart));

    return recordings;
  }

  Future<void> save(Recording rec) async {
    final file = File("$dataDir/${rec.id}.json");
    await file.writeAsString(jsonEncode(rec.toJson()));
  }

  Future<void> delete(Recording rec) async {
    final file = File("$dataDir/${rec.id}.json");
    if (await file.exists()) {
      await file.delete();
    }
  }
}
