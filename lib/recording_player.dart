import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import 'recording.dart'; // tvoj Recording model

class RecordingPlayer extends StatefulWidget {
  final Recording rec;

  const RecordingPlayer({super.key, required this.rec});

  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  late AudioPlayer _player;
  Duration? _duration;
  Duration _position = Duration.zero;
  bool _isReady = false;

  Duration get _highlightStart =>
      widget.rec.highlightStart.difference(DateTime.parse("${widget.rec.date}T00:00:00"));
  Duration get _highlightEnd =>
      widget.rec.highlightEnd.difference(DateTime.parse("${widget.rec.date}T00:00:00"));

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _player = AudioPlayer();
    try {
      await _player.setFilePath(widget.rec.path);
      _duration = await _player.durationFuture;
      _isReady = true;

      // seek odmah na highlightStart
      await _player.seek(_highlightStart);
      setState(() {});
    } catch (e) {
      print("❌ Player error: $e");
    }

    _player.positionStream.listen((pos) {
      setState(() {
        _position = pos;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final ms = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$ms:$ss";
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Text("Loading audio...", style: TextStyle(color: Colors.grey));
    }

    final total = _duration ?? Duration.zero;
    final highlightStart = _highlightStart.inMilliseconds.toDouble();
    final highlightEnd = _highlightEnd.inMilliseconds.toDouble();

    final pos = _position.inMilliseconds.toDouble().clamp(0, total.inMilliseconds.toDouble());

    return Column(
      children: [
        // Seek bar sa highlight overlay
        Stack(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.green,
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: Colors.white,
                trackHeight: 4,
              ),
              child: Slider(
                value: pos,
                min: 0,
                max: total.inMilliseconds.toDouble(),
                onChanged: (val) async {
                  final newPos = Duration(milliseconds: val.toInt());
                  await _player.seek(newPos);
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final startPercent = highlightStart / total.inMilliseconds;
                    final endPercent = highlightEnd / total.inMilliseconds;

                    return Row(
                      children: [
                        Expanded(flex: (startPercent * 1000).toInt(), child: Container()),
                        Container(
                          width: constraints.maxWidth * (endPercent - startPercent),
                          height: 4,
                          color: Colors.orange.withOpacity(0.5),
                        ),
                        Expanded(
                          flex: (1000 - (endPercent * 1000).toInt()),
                          child: Container(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          ],
        ),

        // vreme
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatTime(_position), style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text(_formatTime(total), style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),

        // kontrole
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_5, color: Colors.orange),
              onPressed: () async {
                final newPos = _position - const Duration(seconds: 5);
                await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
              },
            ),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                if (playing) {
                  return IconButton(
                    icon: const Icon(Icons.pause_circle_filled, color: Colors.green, size: 40),
                    onPressed: () => _player.pause(),
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 40),
                    onPressed: () => _player.play(),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_5, color: Colors.orange),
              onPressed: () async {
                final newPos = _position + const Duration(seconds: 5);
                if (_duration != null && newPos > _duration!) {
                  await _player.seek(_duration);
                } else {
                  await _player.seek(newPos);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: () async {
                await _player.pause();
                await _player.seek(_highlightStart);
              },
            ),
          ],
        )
      ],
    );
  }
}
