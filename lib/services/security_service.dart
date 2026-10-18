import 'package:flutter/services.dart';

class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.pocket.pocket/security');

  static Future<bool> isDeviceSecure() async {
    try {
      final secure = await _channel.invokeMethod<bool>('isDeviceSecure');
      return secure ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      final success = await _channel.invokeMethod<bool>('authenticate');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}
