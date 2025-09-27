class Recording {
  final String id;
  String title;
  String date;
  String duration;
  String path;
  String status; // "processing" | "complete"
  bool pinned;
  String? notes;
  Duration highlightStart;
  Duration highlightEnd;

  // UI state
  bool expanded;
  bool showDone;

  Recording({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    required this.path,
    required this.status,
    required this.pinned,
    this.notes,
    required this.highlightStart,
    required this.highlightEnd,
    this.expanded = false,
    this.showDone = false,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    final startIso = json["highlighted"]["start"] as String;
    final endIso = json["highlighted"]["end"] as String;
    final startDt = DateTime.parse(startIso);
    final endDt = DateTime.parse(endIso);

    // izvuci početak snimka iz ID-a, npr "250926_140459_140500"
    final parts = (json["id"] as String).split("_");
    final datePart = parts[0]; // "250926"
    final timePart = parts[1]; // "140459"

    final year = 2000 + int.parse(datePart.substring(0, 2));
    final month = int.parse(datePart.substring(2, 4));
    final day = int.parse(datePart.substring(4, 6));
    final hour = int.parse(timePart.substring(0, 2));
    final minute = int.parse(timePart.substring(2, 4));
    final second = int.parse(timePart.substring(4, 6));

    final fileStart = DateTime(year, month, day, hour, minute, second);

    final durStart = startDt.difference(fileStart);
    final durEnd = endDt.difference(fileStart);

    return Recording(
      id: json["id"],
      title: json["title"],
      date: json["date"],
      duration: json["duration"],
      path: json["path"],
      status: json["status"],
      pinned: json["pinned"] ?? false,
      notes: json["notes"],
      highlightStart: durStart.isNegative ? Duration.zero : durStart,
      highlightEnd: durEnd.isNegative ? Duration.zero : durEnd,
    );
  }

  Map<String, dynamic> toJson() {
    // isto parsiranje kao gore
    final parts = id.split("_");
    final datePart = parts[0];
    final timePart = parts[1];

    final year = 2000 + int.parse(datePart.substring(0, 2));
    final month = int.parse(datePart.substring(2, 4));
    final day = int.parse(datePart.substring(4, 6));
    final hour = int.parse(timePart.substring(0, 2));
    final minute = int.parse(timePart.substring(2, 4));
    final second = int.parse(timePart.substring(4, 6));

    final fileStart = DateTime(year, month, day, hour, minute, second);

    return {
      "id": id,
      "title": title,
      "date": date,
      "duration": duration,
      "path": path,
      "status": status,
      "pinned": pinned,
      "notes": notes,
      "highlighted": {
        "start": fileStart.add(highlightStart).toIso8601String(),
        "end": fileStart.add(highlightEnd).toIso8601String(),
      },
    };
  }
}
