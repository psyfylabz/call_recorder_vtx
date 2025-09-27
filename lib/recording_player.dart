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
  late final AudioPlayer _player;
  Duration? _duration;
  Duration _position = Duration.zero;
  bool _readyFired = false;

  Duration get _highlightStart =>
      Duration(seconds: widget.rec.highlightOffset);
  Duration get _highlightEnd =>
      Duration(seconds: widget.rec.highlightOffset + widget.rec.highlightLength);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.rec.path);

      _player.durationStream.listen((dur) {
        if (!mounted) return;
        if (dur != null) setState(() => _duration = dur);
      });

      _player
          .createPositionStream(
            steps: 100,
            minPeriod: const Duration(milliseconds: 50),
            maxPeriod: const Duration(milliseconds: 200),
          )
          .listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });

      _player.processingStateStream.listen((state) async {
        if (!mounted) return;
        if (state == ProcessingState.ready && !_readyFired) {
          _readyFired = true;
          await _player.seek(_highlightStart);
          setState(() => _position = _highlightStart);
          await _player.play();
        }
      });
    } catch (e) {
      debugPrint("❌ Player init error: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    if (_duration == null) {
      return const Text("Loading audio...",
          style: TextStyle(color: Colors.grey));
    }

    final totalMs = _duration!.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              setState(() => _position = newPos);
            },
          ),
        ),

        // levo = trenutna pozicija; desno = highlight raspon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(_position),
              style: TextStyle(
                color: (_position >= _highlightStart &&
                        _position <= _highlightEnd)
                    ? Colors.orange
                    : Colors.white,
                fontSize: 12,
              ),
            ),
            Text(
              "${_fmt(_highlightStart)} - ${_fmt(_highlightEnd)}",
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),

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
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return IconButton(
                  icon: Icon(
                    playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.green,
                    size: 40,
                  ),
                  onPressed: () async {
                    if (_duration != null && _position >= _duration!) {
                      await _player.seek(_highlightStart);
                      setState(() => _position = _highlightStart);
                    }
                    playing ? await _player.pause() : await _player.play();
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_5, color: Colors.orange),
              onPressed: () async {
                final newPos = _position + const Duration(seconds: 5);
                await _player.seek(
                  (_duration != null && newPos > _duration!)
                      ? _duration
                      : newPos,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: () async {
                await _player.pause();
                await _player.seek(_highlightStart);
                setState(() => _position = _highlightStart);
              },
            ),
          ],
        ),
      ],
    );
  }
}
