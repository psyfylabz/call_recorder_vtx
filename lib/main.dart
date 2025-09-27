import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool pinned; // 🔹 dodato

  Recording({
    required this.title,
    required this.date,
    required this.duration,
    this.expanded = false,
    this.showDone = false,
    this.notes,
    this.fromProcessing = true,
    this.pinned = false, // 🔹 default false
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

  bool _serviceEnabled = true; // switch state

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
    _loadServiceState();
    _loadServiceState();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.audio.request();
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }
    await Permission.phone.request();
  }

  Future<void> _loadServiceState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serviceEnabled = prefs.getBool("service_enabled") ?? true;
    });
  }

  Future<void> _saveServiceState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("service_enabled", value);
    setState(() {
      _serviceEnabled = value;
    });
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

      // Drawer meni
      drawer: Drawer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text(
                "Menu",
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bubble_chart),
              title: const Text("Enable Bubble Service"),
              trailing: Switch(
                value: _serviceEnabled,
                onChanged: (val) async {
                  setState(() {
                    _serviceEnabled = val;
                  });
                  await _saveServiceState(val);
                  // 👉 ovde više ne pokrećemo ili gasimo bubble direktno
                },
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Made by cyberp",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
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
    // 🔹 prvo odvajamo pinovane
    final pinnedItems = <Recording>[];
    for (var entry in grouped.entries) {
      for (var rec in entry.value) {
        if (rec.pinned) pinnedItems.add(rec);
      }
    }

    return ListView(
      children: [
        if (pinnedItems.isNotEmpty) ...[
          Container(
            color: Colors.grey[850],
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text("Pinned",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
          ...pinnedItems.map((rec) =>
            _buildItem(rec, rec.date, grouped[rec.date] ?? [], isProcessing)),
        ],

        // ostatak grupe
        ...grouped.entries
            .where((entry) =>
                entry.value.any((rec) => !rec.pinned)) // skip pinovane
            .map((entry) {
          final date = entry.key;
          final items = entry.value.where((r) => !r.pinned).toList();

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
              ...items.map((rec) => _buildItem(rec, date, entry.value, isProcessing)),
            ],
          );
        }).toList(),
      ],
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
                          if (value == "pin") {
                            rec.pinned = true;
                          } else if (value == "unpin") {
                            rec.pinned = false;
                          } else if (value == "delete") {
                            items.remove(rec);
                          } else if (value == "add_notes") {
                            _showNotesDialog(rec);
                          } else if (value == "move_to_complete") {
                            complete.putIfAbsent(date, () => []);
                            complete[date]!.add(rec..fromProcessing = false);
                            items.remove(rec);
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: rec.pinned ? "unpin" : "pin",
                          child: Text(rec.pinned ? "Unpin this" : "Pin this"),
                        ),
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
                    )
                  )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    setState(() {
                      if (value == "pin") {
                        rec.pinned = true;
                      } else if (value == "unpin") {
                        rec.pinned = false;
                      } else if (value == "delete") {
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
                    PopupMenuItem(
                      value: rec.pinned ? "unpin" : "pin",
                      child: Text(rec.pinned ? "Unpin this" : "Pin this"),
                    ),
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
