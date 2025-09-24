import 'package:flutter/material.dart';
import 'recording_overlay.dart'; // import overlay fajla

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

  Recording({
    required this.title,
    required this.date,
    required this.duration,
    this.expanded = false,
    this.showDone = false,
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

  final Map<String, List<Recording>> processing = {
    "Friday 19 September 2025": [
      Recording(
          title: "Call with +381691123055",
          date: "2025-09-19",
          duration: "01:10"),
      Recording(
          title: "Call with +381601234567",
          date: "2025-09-19",
          duration: "02:43"),
    ],
    "Thursday 18 September 2025": [
      Recording(
          title: "Voice Note (Reminder)",
          date: "2025-09-18",
          duration: "00:30"),
    ],
  };

  final Map<String, List<Recording>> complete = {
    "Wednesday 17 September 2025": [
      Recording(
          title: "Call with +381621234567",
          date: "2025-09-17",
          duration: "01:45"),
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Call Recorder VTX"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Processing"),
            Tab(text: "Complete"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildList(processing, isProcessing: true),
          buildList(complete, isProcessing: false),
        ],
      ),

      /// Floating dugme koje otvara/zatvara overlay
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

  Widget buildList(Map<String, List<Recording>> grouped,
      {required bool isProcessing}) {
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
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      rec.expanded
                          ? Icons.pause_circle
                          : Icons.play_circle_fill,
                      color: Colors.green,
                    ),
                    title: Text(rec.title),
                    subtitle: Text("Duration: ${rec.duration}"),
                    trailing: isProcessing
                        ? (rec.showDone
                        ? GestureDetector(
                      onTap: () {
                        setState(() {
                          complete.putIfAbsent(date, () => []);
                          complete[date]!.add(rec);
                          items.remove(rec);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Moved to Complete")),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: double.infinity,
                        color: Colors.green.withOpacity(0.2),
                        child: const Icon(Icons.check,
                            color: Colors.green, size: 28),
                      ),
                    )
                        : null)
                        : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.grey),
                      onSelected: (value) {
                        setState(() {
                          if (value == "delete") {
                            items.remove(rec);
                          } else if (value == "restore") {
                            processing.putIfAbsent(date, () => []);
                            processing[date]!.add(rec);
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
                          value: "restore",
                          child: Text("Restore"),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (isProcessing && rec.showDone) {
                        setState(() {
                          rec.showDone = false;
                        });
                      } else if (isProcessing) {
                        setState(() {
                          rec.expanded = !rec.expanded;
                        });
                      }
                    },
                    onLongPress: isProcessing
                        ? () {
                      setState(() {
                        rec.showDone = true;
                      });
                    }
                        : null,
                  ),
                  if (rec.expanded && isProcessing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.stop, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                rec.expanded = false;
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
            })
          ],
        );
      }).toList(),
    );
  }
}
