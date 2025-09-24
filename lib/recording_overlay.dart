import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Widget koji se prikazuje u overlay prozoru
class RecordingOverlay extends StatefulWidget {
  const RecordingOverlay({super.key});

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay> {
  bool isRecording = false;

  void _toggleRecording() {
    setState(() {
      isRecording = !isRecording;
    });

    if (isRecording) {
      Fluttertoast.showToast(msg: "Recording started (overlay)");
    } else {
      Fluttertoast.showToast(msg: "Recording stopped (overlay)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isRecording ? Colors.red : Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(2, 2),
              )
            ],
          ),
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

/// Servis za kontrolu overlay prozora
class RecordingOverlayService {
  /// Prikaži overlay
  static Future<void> showOverlay() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted != true) {
      await FlutterOverlayWindow.requestPermission();
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Call Recorder Overlay",
      overlayContent: "Mic button",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.centerRight,
      visibility: NotificationVisibility.visibilityPublic,
      height: 120,
      width: 120,
    );
  }

  /// Zatvori overlay
  static Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  /// Da li je overlay aktivan
  static Future<bool> isActive() async {
    return await FlutterOverlayWindow.isActive();
  }
}
