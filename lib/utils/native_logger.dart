import 'package:flutter/services.dart';

class NativeLogger {
  static const platform = MethodChannel('pink.poche.potunes.logger');

  static Future<void> log(String message, {String level = 'debug'}) async {
    try {
      await platform.invokeMethod('log', {
        'message': message,
        'level': level,
      });
    } catch (e) {
      print("Failed to send native log: $e");
    }
  }

  static void handleNativeLog(MethodCall call) {
    final message = call.arguments['message'] as String?;
    final level = call.arguments['level'] as String?;

    switch (level) {
      case 'debug':
        print('Native[D]: $message');
        break;
      case 'error':
        print('Native[E]: $message');
        break;
      default:
        print('Native: $message');
    }
  }
}
