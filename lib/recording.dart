class Recording {
  final String id;
  String title; // broj telefona ili ime
  String date;  // yyyy-MM-dd
  String path;  // putanja do snimka
  String status; // "processing" | "complete"
  bool pinned;
  String? notes;

  /// Highlight meta – čuvamo offset i dužinu u sekundama
  int highlightOffset;
  int highlightLength;

  // UI state (nije deo JSON-a)
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

  factory Recording.fromJson(Map<String, dynamic> json) {
    final highlighted = json["highlighted"] ?? {};
    return Recording(
      id: json["id"],
      title: json["title"],
      date: json["date"],
      path: json["path"],
      status: json["status"],
      pinned: json["pinned"] ?? false,
      notes: json["notes"],
      highlightOffset: highlighted["offset"] ?? 0,
      highlightLength: highlighted["length"] ?? 0,
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
      "highlighted": {
        "offset": highlightOffset,
        "length": highlightLength,
      },
    };
  }

  /// Izračunaj highlight start kao Duration
  Duration get highlightStart => Duration(seconds: highlightOffset);

  /// Izračunaj highlight end kao Duration
  Duration get highlightEnd =>
      Duration(seconds: highlightOffset + highlightLength);
}
