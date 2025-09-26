import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'recording_overlay.dart';

void main() {
  runApp(const CallRecorderApp());
}

class CallRecorderApp extends StatelessWidget {
  const CallRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Call Recorder VTX",
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const RecordingsScreen(),
    );
  }
}

class Recording {
  final String title;
  final String date;
  final String duration;
  bool expanded;
  bool showDone;
  String? notes;
  bool fromProcessing;

  Recording({
    required this.title,
    required this.date,
    required this.duration,
    this.expanded = false,
    this.showDone = false,
    this.notes,
    this.fromProcessing = true,
  });
}

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isSearching = false;
  String _searchQuery = "";
  Recording? _expandedRec;

  final Map<String, List<Recording>> processing = {
    "Friday 19 September 2025": [
      Recording(
          title: "Call with +381691123055",
          date: "2025-09-19",
          duration: "01:10",
          fromProcessing: true),
      Recording(
          title: "Call with +381601234567",
          date: "2025-09-19",
          duration: "02:43",
          fromProcessing: true),
    ],
    "Thursday 18 September 2025": [
      Recording(
          title: "Voice Note (Reminder)",
          date: "2025-09-18",
          duration: "00:30",
          fromProcessing: true),
    ],
  };

  final Map<String, List<Recording>> complete = {
    "Wednesday 17 September 2025": [
      Recording(
          title: "Call with +381621234567",
          date: "2025-09-17",
          duration: "01:45",
          fromProcessing: false),
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Storage (za starije verzije)
    await Permission.storage.request();

    // Android 13+ media perms
    await Permission.audio.request();

    // Overlay
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }

    // Phone (READ_PHONE_STATE + READ_CALL_LOG)
    await Permission.phone.request();
  }


  @override
  Widget build(BuildContext context) {
    final results = _isSearching ? _searchResults() : null;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search recordings...",
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              )
            : const Text("Call Recorder VTX"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchQuery = "";
              });
            },
          ),
        ],
        bottom: !_isSearching
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Processing"),
                  Tab(text: "Complete"),
                ],
              )
            : null,
      ),
      body: _isSearching
          ? buildList(results!, isProcessing: true, isSearch: true)
          : TabBarView(
              controller: _tabController,
              children: [
                buildList(processing, isProcessing: true),
                buildList(complete, isProcessing: false),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () async {
          if (await RecordingOverlayService.isActive()) {
            await RecordingOverlayService.closeOverlay();
          } else {
            await RecordingOverlayService.showOverlay();
          }
        },
        child: const Icon(Icons.mic, color: Colors.white),
      ),
    );
  }

  /// Spoji processing i complete u jednu mapu za search
  Map<String, List<Recording>> _searchResults() {
    final combined = <String, List<Recording>>{};

    void addItems(Map<String, List<Recording>> source) {
      for (var entry in source.entries) {
        final matches = entry.value.where((rec) {
          final searchIn = [
            rec.title.toLowerCase(),
            rec.notes?.toLowerCase() ?? ""
          ];
          return searchIn.any((field) => field.contains(_searchQuery));
        }).toList();

        if (matches.isNotEmpty) {
          combined.putIfAbsent(entry.key, () => []);
          combined[entry.key]!.addAll(matches);
        }
      }
    }

    addItems(processing);
    addItems(complete);

    return combined;
  }

  Widget buildList(Map<String, List<Recording>> grouped,
      {required bool isProcessing, bool isSearch = false}) {
    return ListView(
      children: grouped.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) {
        final date = entry.key;
        final items = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.grey[900],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(date,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ...items.map((rec) {
              final effectiveProcessing =
                  isSearch ? rec.fromProcessing : isProcessing;
              return _buildItem(rec, date, items, effectiveProcessing);
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildItem(
      Recording rec, String date, List<Recording> items, bool isProcessing) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            rec.expanded ? Icons.pause_circle : Icons.play_circle_fill,
            color: isProcessing ? Colors.green : Colors.orange,
          ),
          title: Text(rec.title),
          subtitle: Text(
            "Duration: ${rec.duration}"
            "${rec.notes != null ? "\nNotes: ${rec.notes}" : ""}",
          ),
          trailing: isProcessing
              ? (rec.showDone
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          complete.putIfAbsent(date, () => []);
                          complete[date]!.add(rec..fromProcessing = false);
                          items.remove(rec);
                          rec.showDone = false;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: double.infinity,
                        color: Colors.green.withOpacity(0.2),
                        child: const Icon(Icons.check,
                            color: Colors.green, size: 28),
                      ),
                    )
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) {
                        setState(() {
                          if (value == "delete") {
                            items.remove(rec);
                          } else if (value == "add_notes") {
                            _showNotesDialog(rec);
                          } else if (value == "move_to_complete") {
                            complete.putIfAbsent(date, () => []);
                            complete[date]!
                                .add(rec..fromProcessing = false);
                            items.remove(rec);
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "delete",
                          child: Text("Delete"),
                        ),
                        const PopupMenuItem(
                          value: "add_notes",
                          child: Text("Add notes"),
                        ),
                        const PopupMenuItem(
                          value: "move_to_complete",
                          child: Text("Move to Complete"),
                        ),
                      ],
                    ))
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    setState(() {
                      if (value == "delete") {
                        items.remove(rec);
                      } else if (value == "add_notes") {
                        _showNotesDialog(rec);
                      } else if (value == "restore") {
                        processing.putIfAbsent(date, () => []);
                        processing[date]!.add(rec..fromProcessing = true);
                        items.remove(rec);
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: "delete",
                      child: Text("Delete"),
                    ),
                    const PopupMenuItem(
                      value: "add_notes",
                      child: Text("Add notes"),
                    ),
                    const PopupMenuItem(
                      value: "restore",
                      child: Text("Restore"),
                    ),
                  ],
                ),
          onTap: () {
            setState(() {
              if (_expandedRec == rec) {
                _expandedRec = null;
                rec.expanded = false;
              } else {
                _expandedRec?.expanded = false;
                _expandedRec = rec;
                rec.expanded = true;
              }
            });
          },
          onLongPress: isProcessing
              ? () {
                  setState(() {
                    rec.showDone = !rec.showDone;
                  });
                }
              : null,
        ),
        if (rec.expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      rec.expanded = false;
                      _expandedRec = null;
                    });
                  },
                ),
                const Text("Player controls here...",
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        const Divider(
          thickness: 0.5,
          height: 1,
          color: Colors.grey,
        ),
      ],
    );
  }

  void _showNotesDialog(Recording rec) {
    final controller = TextEditingController(text: rec.notes ?? "");
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Notes"),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  rec.notes = controller.text;
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
