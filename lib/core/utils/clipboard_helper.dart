import 'dart:async';
import 'package:flutter/services.dart';

/// Helper for copying sensitive strings with automatic clipboard clearing after 30 seconds
class ClipboardHelper {
  ClipboardHelper._();

  static Timer? _clearTimer;

  static Future<void> copySensitive(String text, {int clearAfterSeconds = 30}) async {
    await Clipboard.setData(ClipboardData(text: text));

    _clearTimer?.cancel();
    _clearTimer = Timer(Duration(seconds: clearAfterSeconds), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
  }
}
