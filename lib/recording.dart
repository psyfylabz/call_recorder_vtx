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
    // start snimka iz ID-a, npr: 250926_140459_140500
    final parts = (json["id"] as String).split("_");
    final datePart = parts[0]; // 250926
    final startPart = parts[1]; // 140459

    final fileStart = DateTime(
      2000 + int.parse(datePart.substring(0, 2)), // 25 -> 2025
      int.parse(datePart.substring(2, 4)),       // 09
      int.parse(datePart.substring(4, 6)),       // 26
      int.parse(startPart.substring(0, 2)),      // 14
      int.parse(startPart.substring(2, 4)),      // 04
      int.parse(startPart.substring(4, 6)),      // 59
    );

    final startDt = DateTime.parse(json["highlighted"]["start"]);
    final endDt   = DateTime.parse(json["highlighted"]["end"]);

    return Recording(
      id: json["id"],
      title: json["title"],
      date: json["date"],
      duration: json["duration"],
      path: json["path"],
      status: json["status"],
      pinned: json["pinned"] ?? false,
      notes: json["notes"],
      highlightStart: startDt.difference(fileStart),
      highlightEnd: endDt.difference(fileStart),
    );
  }


  Map<String, dynamic> toJson() {
    final base = DateTime.parse("${date}T00:00:00");
    final start = base.add(highlightStart);
    final end = base.add(highlightEnd);

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
        "start": start.toIso8601String(),
        "end": end.toIso8601String(),
      },
    };
  }
}
