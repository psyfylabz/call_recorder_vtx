import 'dart:io';
import 'package:intl/intl.dart';

class RecordingUtils {
  static const samsungDir = "/storage/emulated/0/Recordings/Call";

  /// Vraća mapu sa meta podacima o poslednjem Samsung snimku
  static Future<Map<String, dynamic>?> getLastSamsungRecording() async {
    final dir = Directory(samsungDir);
    if (!await dir.exists()) return null;

    final files = dir
        .listSync()
        .where((f) => f is File && f.path.endsWith(".m4a"))
        .map((f) => File(f.path))
        .toList();

    if (files.isEmpty) return null;

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final last = files.first;

    final name = last.uri.pathSegments.last;
    // Call recording +381600731955_250926_140459.m4a
    final parts = name.replaceAll("Call recording ", "").split("_");

    if (parts.length < 3) return null;

    final number = parts[0];
    final rawDate = parts[1]; // 250926
    final rawTime = parts[2].split(".").first; // 140459

    final date = "20${rawDate.substring(0, 2)}-${rawDate.substring(2, 4)}-${rawDate.substring(4, 6)}";
    final callTime = "${rawTime.substring(0, 2)}:${rawTime.substring(2, 4)}:${rawTime.substring(4, 6)}";

    return {
      "number": number,
      "date": date,
      "time": callTime,
      "file": last.path,
      "rawTime": rawTime,
    };
  }

  /// Generiše ID na osnovu podataka i offseta
  static String makeId(String rawDate, String rawTime, int offsetSec) {
    final base = "${rawDate}_${rawTime}";
    // rawTime je HHMMSS → pretvori u sekunde pa dodaj offset
    final h = int.parse(rawTime.substring(0, 2));
    final m = int.parse(rawTime.substring(2, 4));
    final s = int.parse(rawTime.substring(4, 6));

    final totalSec = h * 3600 + m * 60 + s;
    final newSec = totalSec + offsetSec;

    final nh = (newSec ~/ 3600).toString().padLeft(2, '0');
    final nm = ((newSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final ns = (newSec % 60).toString().padLeft(2, '0');

    final newTime = "$nh$nm$ns";
    return "${rawDate}_${rawTime}_$newTime";
  }
}
