class Recording {
  final String id;
  String title;
  String date; // YYYY-MM-DD
  String duration; // "mm:ss" highlight trajanje
  String path; // putanja do Samsung audio fajla
  String status; // "processing" | "complete"
  bool pinned;
  String? notes;
  DateTime highlightStart;
  DateTime highlightEnd;

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
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json["id"],
      title: json["title"],
      date: json["date"],
      duration: json["duration"],
      path: json["path"],
      status: json["status"],
      pinned: json["pinned"] ?? false,
      notes: json["notes"],
      highlightStart: DateTime.parse(json["highlighted"]["start"]),
      highlightEnd: DateTime.parse(json["highlighted"]["end"]),
    );
  }

  Map<String, dynamic> toJson() {
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
        "start": highlightStart.toIso8601String(),
        "end": highlightEnd.toIso8601String(),
      },
    };
  }
}
