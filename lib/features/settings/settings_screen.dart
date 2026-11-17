import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalahoo_app/features/permissions/permission_service.dart';
import 'package:dalahoo_app/features/permissions/permission_wizard_controller.dart';
import 'package:dalahoo_app/widgets/header_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color backgroundColor = Color(0xFFF2F3FA);
  static const Color primaryBlue = Color(0xFF0099F1);

  bool smsGranted = false;
  bool phoneGranted = false;
  bool batteryOptimized = false;
  bool isHuawei = false;
  int selectedSim = 1;

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  Future<void> loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final sms = (await Permission.sms.status).isGranted;
    final phone = (await Permission.phone.status).isGranted;
    final battery = await PermissionService.isBatteryOptimized();
    final brand = await PermissionService.getDeviceBrand();

    if (!mounted) return;
    setState(() {
      smsGranted = sms;
      phoneGranted = phone;
      batteryOptimized = battery;
      isHuawei = brand.contains('huawei') || brand.contains('honor');
      selectedSim = prefs.getInt('selectedSim') ?? 1;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _card({
    required String title,
    required String status,
    required bool ok,
    required String guide,
    required String buttonText,
    required VoidCallback onPressed,
    Widget? extra,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                color: ok ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(guide, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            if (extra != null) ...[extra, const SizedBox(height: 12)],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("دسترسی‌ها"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const HeaderBackground(height: 130),
          Column(
            children: [
              const SizedBox(height: 130),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _card(
                        title: "۱. دسترسی پیامک",
                        status: smsGranted
                            ? "✅ دسترسی پیامک فعال است"
                            : "❌ دسترسی پیامک داده نشده",
                        ok: smsGranted,
                        guide: "برای خواندن و فوروارد پیامک‌ها لازم است.",
                        buttonText: smsGranted
                            ? "بررسی دسترسی"
                            : "دادن دسترسی پیامک",
                        onPressed: () async {
                          if (smsGranted) {
                            _snack("دسترسی پیامک هم‌اکنون فعال است");
                            return;
                          }
                          await PermissionWizard.ensureSmsPermission(
                            context,
                            () => mounted,
                          );
                          if (mounted) loadStatus();
                        },
                      ),
                      _card(
                        title: "۲. دسترسی سیم‌کارت",
                        status: phoneGranted
                            ? "✅ دسترسی سیم‌کارت فعال است"
                            : "❌ دسترسی سیم‌کارت داده نشده",
                        ok: phoneGranted,
                        guide:
                            "برای شناسایی سیم ۲ و ارسال پیامک از آن لازم است.",
                        buttonText: phoneGranted
                            ? "بررسی دسترسی"
                            : "دادن دسترسی سیم‌کارت",
                        onPressed: () async {
                          if (phoneGranted) {
                            _snack("دسترسی سیم‌کارت هم‌اکنون فعال است");
                            return;
                          }
                          final status = await Permission.phone.request();
                          if (!status.isGranted && status.isPermanentlyDenied) {
                            await openAppSettings();
                          }
                          if (mounted) loadStatus();
                        },
                      ),
                      _card(
                        title: "۳. سیم‌کارت ارسال باربرگ",
                        status: "سیم‌کارت انتخابی: سیم $selectedSim",
                        ok: true,
                        guide:
                            "پیامک‌ها از این سیم‌کارت ارسال میشن. دریافت از هر سیم‌کارتی انجام میشه.",
                        extra: DropdownButton<int>(
                          value: selectedSim,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("سیم‌کارت ۱")),
                            DropdownMenuItem(value: 2, child: Text("سیم‌کارت ۲")),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => selectedSim = v);
                          },
                        ),
                        buttonText: "ذخیره انتخاب",
                        onPressed: () async {
                          await PermissionService.setSelectedSim(selectedSim);
                          _snack("سیم‌کارت ارسال ذخیره شد");
                        },
                      ),
                      _card(
                        title: "۴. بهینه‌سازی باتری",
                        status: batteryOptimized
                            ? "❌ بهینه‌سازی باتری فعال است"
                            : "✅ بهینه‌سازی باتری غیرفعال است",
                        ok: !batteryOptimized,
                        guide:
                            "روی دکمه بزن. در صفحه‌ی باز شده، حالت مصرف باتری را روی «بدون محدودیت» بگذار.",
                        buttonText: "باز کردن تنظیمات باتری",
                        onPressed: () async {
                          await PermissionService.openBatterySettings();
                          await Future.delayed(const Duration(seconds: 1));
                          if (mounted) loadStatus();
                        },
                      ),
                      _card(
                        title: "۵. آغاز خودکار پس‌زمینه",
                        status: "⚠️ وضعیت این مورد قابل بررسی خودکار نیست",
                        ok: true,
                        guide: isHuawei
                            ? "روی دکمه بزن، سپس از لیست برنامه‌ها تیک «پیامک بار» را غیرفعال کن تا حالت «مدیریت دستی» بشه."
                            : "روی دکمه بزن، سپس از لیست برنامه‌ها تیک «پیامک بار» را فعال کن.",
                        buttonText: "باز کردن تنظیمات آغاز خودکار",
                        onPressed: () async {
                          await PermissionService.openAutoStartSettings();
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
