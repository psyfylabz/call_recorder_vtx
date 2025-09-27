import 'package:flutter/services.dart';
import 'recording_json_manager.dart';

class RecordingOverlayService {
  static const _ch = MethodChannel('call_recorder_vtx/overlay');

  static Future<void> showOverlay() async {
    final has = await _ch.invokeMethod<bool>('hasPermission') ?? false;
    if (!has) {
      await _ch.invokeMethod('requestPermission');
      return;
    }
    await _ch.invokeMethod('start');
  }

  static Future<void> closeOverlay() async {
    await _ch.invokeMethod('stop');
  }

  static Future<bool> isActive() async {
    return await _ch.invokeMethod<bool>('isActive') ?? false;
  }

  /// 🟢 Poziva se kada user klikne START na bubble ili notifikaciji
  static Future<void> startRecording({
    required String id,
    required String number,
    required String date,
    required String path,
  }) async {
    // native overlay start
    await _ch.invokeMethod('startRecording');

    // kreiramo json
    await RecordingJsonManager.createOnStart(
      id: id,
      title: number,
      date: date,
      path: path,
    );
  }

  /// 🔴 Poziva se kada user klikne STOP ili se razgovor prekine
  static Future<void> stopRecording({
    required String id,
    required int length,
  }) async {
    // native overlay stop
    await _ch.invokeMethod('stopRecording');

    // ažuriramo json
    await RecordingJsonManager.finalizeOnStop(id, length);
  }
}
