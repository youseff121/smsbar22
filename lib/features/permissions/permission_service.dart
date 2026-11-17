import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel('sms_forwarder');

  // SAFE CALLS
  static Future<bool> _safeBoolCall(String method) async {
    try {
      final result = await _channel.invokeMethod(method);
      return result == true;
    } catch (e) {
      debugPrint("MethodChannel error ($method): $e");
      return false;
    }
  }

  static Future<void> _safeVoidCall(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (e) {
      debugPrint("MethodChannel error ($method): $e");
    }
  }

  // DEVICE BRAND
  static Future<String> getDeviceBrand() async {
    try {
      final result = await _channel.invokeMethod('getDeviceBrand');
      return result?.toString() ?? 'unknown';
    } catch (e) {
      debugPrint("getDeviceBrand error: $e");
      return 'unknown';
    }
  }

  // SMS PERMISSION
  // READ_PHONE_STATE هم لازمه: بدونش گوشی لیست سیم‌کارت‌ها رو نمی‌ده و سیم ۲ پیدا نمیشه
  static Future<bool> requestSmsPermission() async {
    if (!(await Permission.sms.status).isGranted) {
      await Permission.sms.request();
    }
    if (!(await Permission.phone.status).isGranted) {
      await Permission.phone.request();
    }
    return isSmsPermissionGranted();
  }

  static Future<bool> isSmsPermissionGranted() async {
    final sms = (await Permission.sms.status).isGranted;
    final phone = (await Permission.phone.status).isGranted;
    return sms && phone;
  }

  /// تست ارسال SMS (native)
  static Future<bool> testSmsSend() {
    return _safeBoolCall('testSmsSend');
  }

  // BATTERY
  static Future<bool> isBatteryOptimized() {
    return _safeBoolCall('isBatteryOptimized');
  }

  static Future<void> openBatterySettings() {
    return _safeVoidCall('openBatterySettings');
  }

  // AUTOSTART
  static Future<bool> isAutoStartEnabled() {
    return _safeBoolCall('isAutoStartEnabled');
  }

  static Future<void> openAutoStartSettings() {
    return _safeVoidCall('openAutoStartSettings');
  }

  // FINAL CHECK
  static Future<PermissionCheckResult> checkAll() async {
    final smsGranted = await requestSmsPermission();
    final smsWorking = smsGranted;

    final batteryOptimized = await isBatteryOptimized();
    final autoStartEnabled = await isAutoStartEnabled();

    return PermissionCheckResult(
      smsGranted: smsWorking,
      batteryOptimized: batteryOptimized,
      autoStartEnabled: autoStartEnabled,
      allGranted: smsWorking && !batteryOptimized && autoStartEnabled,
    );
  }

  static Future<void> setAppEnabled(bool value) async {
    try {
      await _channel.invokeMethod('setAppEnabled', {"enabled": value});
    } catch (e) {
      debugPrint("setAppEnabled error: $e");
    }
  }

  static Future<void> setSelectedSim(int simSlot) async {
    try {
      await _channel.invokeMethod('setSelectedSim', {"simSlot": simSlot});
    } catch (e) {
      debugPrint("setSelectedSim error: $e");
    }
  }
}

// RESULT MODEL
class PermissionCheckResult {
  final bool smsGranted;
  final bool batteryOptimized;
  final bool autoStartEnabled;
  final bool allGranted;

  PermissionCheckResult({
    required this.smsGranted,
    required this.batteryOptimized,
    required this.autoStartEnabled,
    required this.allGranted,
  });
}
