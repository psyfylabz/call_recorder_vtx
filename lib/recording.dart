class Recording {
  final String id;
  String number;       // broj telefona
  String callTime;     // vreme poziva (HH:mm:ss)
  String date;         // YYYY-MM-DD
  String path;
  String status;       // "processing" | "complete"
  bool pinned;
  String? notes;

  int highlightOffset; // u sekundama od početka snimka
  int highlightLength; // trajanje highlight segmenta u sekundama

  // UI state
  bool expanded;
  bool showDone;

  Recording({
    required this.id,
    required this.number,
    required this.callTime,
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
    return Recording(
      id: json["id"],
      number: json["number"] ?? "",
      callTime: json["callTime"] ?? "",
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
      "number": number,
      "callTime": callTime,
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
