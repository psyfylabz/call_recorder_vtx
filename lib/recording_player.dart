import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'recording.dart';

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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.rec.path);

      // slušaj trajanje iz streama
      _player.durationStream.listen((dur) {
        if (dur != null && mounted) {
          setState(() {
            _duration = dur;
            _isReady = true;
          });
        }
      });

      // odmah jump na highlight start i postavi poziciju
      await _player.seek(widget.rec.highlightStart);
      setState(() {
        _position = widget.rec.highlightStart;
      });

      // autoplay
      await _player.play();
    } catch (e) {
      debugPrint("❌ Player error: $e");
    }

    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
          if (_position >= widget.rec.highlightEnd) {
            _player.pause();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _duration == null) {
      return const Text("Loading audio...",
          style: TextStyle(color: Colors.grey));
    }

    final totalMs = _duration!.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble();
    final startMs = widget.rec.highlightStart.inMilliseconds.toDouble();
    final endMs = widget.rec.highlightEnd.inMilliseconds.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Slider sa narandžastim highlight overlayem
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
                value: posMs.clamp(0, totalMs),
                min: 0,
                max: totalMs,
                onChanged: (val) async {
                  final newPos = Duration(milliseconds: val.toInt());
                  await _player.seek(newPos);
                  setState(() {
                    _position = newPos;
                  });
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final startPercent = startMs / totalMs;
                    final endPercent = endMs / totalMs;
                    final left = constraints.maxWidth * startPercent;
                    final width = constraints.maxWidth * (endPercent - startPercent);
                    return Stack(
                      children: [
                        Positioned(
                          left: left,
                          width: width,
                          top: 0,
                          bottom: 0,
                          child: Container(color: Colors.orange.withOpacity(0.4)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),


        // Timestamp
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(_position),
              style: TextStyle(
                color: (_position >= widget.rec.highlightStart &&
                        _position <= widget.rec.highlightEnd)
                    ? Colors.orange
                    : Colors.white,
                fontSize: 12,
              ),
            ),
            Text(
              _formatTime(_duration!),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),

        // Kontrole
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    icon: const Icon(Icons.pause_circle_filled,
                        color: Colors.green, size: 40),
                    onPressed: () => _player.pause(),
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.play_circle_fill,
                        color: Colors.green, size: 40),
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
                await _player.seek(widget.rec.highlightStart);
                setState(() {
                  _position = widget.rec.highlightStart;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
