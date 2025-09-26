import 'package:flutter/services.dart';

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
}
