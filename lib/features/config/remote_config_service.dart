import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigService {
  // ذخیره در FlutterSharedPreferences با کلید flutter.remote_config (برای SmsReceiver)
  static const String _key = 'remote_config';
  static const String _lastFetchKey = 'config_last_fetch_ms';

  /// بازه حداقل بین دو دریافت موفق کانفیگ
  static const Duration minInterval = Duration(hours: 24);

  // مقادیر پیش‌فرض (با پیش‌شماره ۹۸)
  static const List<String> defaultSenders = [
    '9820007777',
    '9830001923',
    '98200013333',
  ];
  static const List<String> defaultDestinations = [
    '5000200050',
  ];

  // اول هاست اصلی، بعد هاست پشتیبان
  static const List<String> _fallbackSources = [
    'https://your-host.example.com/dalahoo/config.json',
    'https://your-host2.example.com/dalahoo/config.json',
  ];

  static Future<List<String>> loadSenders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = _cached(prefs);
      final list = decoded?['senders'];
      if (list is List && list.isNotEmpty) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return defaultSenders;
  }

  static Map<String, dynamic>? _cached(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static const MethodChannel _native = MethodChannel('sms_forwarder');

  static Future<String> checkAndUpdate() async {
    try {
      // آپدیت دستی: force تا محدودیت ۲۴ ساعت دور زده شود
      await refresh(force: true);
      final prefs = await SharedPreferences.getInstance();
      final app = _cached(prefs)?['app'];
      if (app is! Map || app['version'] == null || app['url'] == null) {
        return 'اطلاعات آپدیت پیدا نشد';
      }
      final remoteVersion = app['version'].toString().trim();
      final url = app['url'].toString().trim();

      final currentVersion =
          (await _native.invokeMethod<String>('getAppVersion')) ?? '';
      if (remoteVersion == currentVersion) {
        return 'برنامه آخرین نسخه است';
      }
      if (!url.startsWith('https://')) {
        return 'آدرس آپدیت معتبر نیست';
      }

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 3));
      if (res.statusCode != 200) {
        return 'دانلود آپدیت انجام نشد';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update.apk');
      await file.writeAsBytes(res.bodyBytes, flush: true);

      await _native.invokeMethod('installApk', {'path': file.path});
      return 'فایل آپدیت آماده شد، نصب رو تایید کن';
    } catch (e) {
      debugPrint('update failed: $e');
      return 'بروزرسانی انجام نشد';
    }
  }

  /// دریافت کانفیگ از سرور.
  /// به‌صورت پیش‌فرض حداکثر هر ۲۴ ساعت یک‌بار اجرا می‌شود.
  /// برای اجبار (مثلاً دکمه آپدیت) [force] را true بگذار.
  static Future<void> refresh({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final last = prefs.getInt(_lastFetchKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (last > 0 && now - last < minInterval.inMilliseconds) {
        debugPrint('remote config skip: within 24h window');
        return;
      }
    }

    final cachedSources = (_cached(prefs)?['sources'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.startsWith('https://'))
            .toList() ??
        <String>[];

    // اول منابع کش‌شده، بعد منابع داخل اپ (هاست ۱ سپس هاست ۲)
    final urls = <String>{...cachedSources, ..._fallbackSources}.toList();

    for (final url in urls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is! Map) continue;

        final senders = decoded['senders'];
        final destinations = decoded['destinations'];
        if (senders is! List ||
            destinations is! List ||
            senders.isEmpty ||
            destinations.isEmpty) {
          continue;
        }

        final newSources = (decoded['sources'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.startsWith('https://'))
                .toList() ??
            cachedSources;

        await prefs.setString(
          _key,
          jsonEncode({
            'senders': senders,
            'destinations': destinations,
            'sources': newSources,
            'app': decoded['app'] ?? _cached(prefs)?['app'],
          }),
        );
        await prefs.setInt(
          _lastFetchKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        debugPrint('remote config updated from $url');
        return;
      } catch (e) {
        debugPrint('remote config failed ($url): $e');
      }
    }
  }
}
