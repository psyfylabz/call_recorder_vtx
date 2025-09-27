class Recording {
  final String id;
  String title;
  String date;
  String path;
  String status; // "processing" | "complete"
  bool pinned;
  String? notes;

  // highlight u sekundama
  int highlightOffset; // u sekundama od početka fajla
  int highlightLength; // trajanje segmenta u sekundama

  // UI state
  bool expanded;
  bool showDone;

  Recording({
    required this.id,
    required this.title,
    required this.date,
    required this.path,
    required this.status,
    required this.pinned,
    this.notes,
    required this.highlightOffset,
    required this.highlightLength,
    this.expanded = false,
    this.showDone = false,
  });

  Duration get highlightStart => Duration(seconds: highlightOffset);
  Duration get highlightEnd =>
      Duration(seconds: highlightOffset + highlightLength);

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json["id"],
      title: json["title"],
      date: json["date"],
      path: json["path"],
      status: json["status"],
      pinned: json["pinned"] ?? false,
      notes: json["notes"],
      highlightOffset: json["highlight"]["offset"] ?? 0,
      highlightLength: json["highlight"]["length"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "date": date,
      "path": path,
      "status": status,
      "pinned": pinned,
      "notes": notes,
      "highlight": {
        "offset": highlightOffset,
        "length": highlightLength,
      },
    };
  }
}
