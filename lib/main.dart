import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recording_overlay.dart';
import 'recording.dart';
import 'recording_player.dart';
import 'package:intl/intl.dart';

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
          popupMenuTheme: const PopupMenuThemeData(
          elevation: 4,
          textStyle: TextStyle(color: Colors.white),
        ),
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const RecordingsScreen(),
    );
  }
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

  bool _serviceEnabled = true;

  List<Recording> allRecordings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestPermissions();
    _loadServiceState();
    _loadRecordings();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.audio.request();
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }
    await Permission.phone.request();
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
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

  Future<void> _loadRecordings() async {
    const folderPath = "/storage/emulated/0/Recordings/VTX Files/Data/";
    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

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
        debugPrint("❌ Failed to parse ${file.path}: $e");
      }
    }

    // sortiranje: prvo po datumu, pa po id (da bude najnovije gore)
    recordings.sort((a, b) {
      final aKey = "${a.date}_${a.id}";
      final bKey = "${b.date}_${b.id}";
      return bKey.compareTo(aKey);
    });

    setState(() {
      allRecordings = recordings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _isSearching ? _searchResults() : allRecordings;

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
                  setState(() => _searchQuery = val.toLowerCase());
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecordings,
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

      drawer: Drawer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text("Menu",
                  style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
            ListTile(
              leading: const Icon(Icons.bubble_chart),
              title: const Text("Enable Bubble Service"),
              trailing: Switch(
                value: _serviceEnabled,
                onChanged: (val) async {
                  setState(() => _serviceEnabled = val);
                  await _saveServiceState(val);
                },
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Made by cyberp",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),

      body: _isSearching
          ? buildList(results, isSearch: true)
          : TabBarView(
              controller: _tabController,
              children: [
                buildList(allRecordings
                    .where((r) => r.status == "processing")
                    .toList()),
                buildList(allRecordings
                    .where((r) => r.status == "complete")
                    .toList()),
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

  List<Recording> _searchResults() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return allRecordings;

    return allRecordings.where((rec) {
      final searchIn = [
        rec.title.toLowerCase(),
        rec.notes?.toLowerCase() ?? ""
      ];
      return searchIn.any((field) => field.contains(query));
    }).toList();
  }

  Widget buildList(List<Recording> recordings, {bool isSearch = false}) {
    final pinnedItems = recordings.where((r) => r.pinned).toList();
    final others = recordings.where((r) => !r.pinned).toList();

    Map<String, List<Recording>> grouped = {};
    for (var rec in others) {
      grouped.putIfAbsent(rec.date, () => []);
      grouped[rec.date]!.add(rec);
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
          ...pinnedItems.map((rec) => _buildItem(rec, rec.date, recordings)),
        ],

        ...grouped.entries.map((entry) {
          final dateStr = entry.key; // npr. "2025-09-07"
          String prettyDate = dateStr;
          try {
            final parsed = DateTime.parse(dateStr);
            prettyDate = DateFormat('EEEE d MMMM yyyy').format(parsed);
          } catch (_) {}

          final items = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.grey[900],
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(prettyDate,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ...items.map((rec) => _buildItem(rec, dateStr, recordings)),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildItem(Recording rec, String date, List<Recording> items) {
    final isProcessing = rec.status == "processing";

    // vreme poziva iz id-a (drugi segment)
    String callTime = "";
    final parts = rec.id.split("_");
    if (parts.length >= 2) {
      final t = parts[1]; // npr. 103917
      if (t.length == 6) {
        callTime = "${t.substring(0, 2)}:${t.substring(2, 4)}"; // HH:mm bez sekundi
      }
    }

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: isProcessing ? Colors.green : Colors.orange,
            child: Icon(
              rec.highlightOffset == 0 ? Icons.mic : Icons.call,
              color: Colors.white,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  rec.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Text(
                callTime.substring(0, 5), // prikaz HH:mm bez sekundi
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  setState(() {
                    if (value == "pin") {
                      rec.pinned = true;
                    } else if (value == "unpin") {
                      rec.pinned = false;
                    } else if (value == "delete") {
                      items.remove(rec);
                      File("/storage/emulated/0/Recordings/VTX Files/Data/${rec.id}.json").delete();
                    } else if (value == "add_notes") {
                      _showNotesDialog(rec);
                    } else if (value == "move_to_complete") {
                      rec.status = "complete";
                    } else if (value == "restore") {
                      rec.status = "processing";
                    }
                    File("/storage/emulated/0/Recordings/VTX Files/Data/${rec.id}.json")
                        .writeAsStringSync(jsonEncode(rec.toJson()));
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: rec.pinned ? "unpin" : "pin",
                    child: Text(rec.pinned ? "Unpin this" : "Pin this"),
                  ),
                  const PopupMenuItem(value: "delete", child: Text("Delete")),
                  const PopupMenuItem(value: "add_notes", child: Text("Add notes")),
                  if (isProcessing)
                    const PopupMenuItem(
                      value: "move_to_complete",
                      child: Text("Move to Complete"),
                    )
                  else
                    const PopupMenuItem(value: "restore", child: Text("Restore")),
                ],
              ),
            ],
          ),
          subtitle: rec.notes != null && rec.notes!.isNotEmpty
              ? Text("Notes: ${rec.notes}")
              : null,
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
              ? () => setState(() => rec.showDone = !rec.showDone)
              : null,
        ),
        if (rec.expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RecordingPlayer(rec: rec),
          ),
        const Divider(thickness: 0.5, height: 1, color: Colors.grey),
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
                setState(() => rec.notes = controller.text);
                File("/storage/emulated/0/Recordings/VTX Files/Data/${rec.id}.json")
                    .writeAsStringSync(jsonEncode(rec.toJson()));
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
