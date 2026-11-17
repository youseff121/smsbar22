import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dalahoo_app/features/permissions/permission_service.dart';
import 'package:dalahoo_app/features/home/home_screen.dart';

class PermissionWizardController extends StatefulWidget {
  const PermissionWizardController({super.key});

  @override
  State<PermissionWizardController> createState() =>
      _PermissionWizardControllerState();
}

class _PermissionWizardControllerState
    extends State<PermissionWizardController> {
  bool _active = true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;
      await PermissionWizard.start(context, isActive: () => _active);
    });
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class PermissionWizard {
  static const MethodChannel _channel = MethodChannel('sms_forwarder');

  static Future<void> start(
    BuildContext context, {
    required bool Function() isActive,
  }) async {
    if (!context.mounted || !isActive()) return;

    final prefs = await SharedPreferences.getInstance();

    final wizardCompleted =
        prefs.getBool('permission_wizard_completed') ?? false;

    // ---------- مسیر برگشت (اپ قبلاً ویزارد را تمام کرده) ----------
    if (wizardCompleted) {
      final savedName = prefs.getString('driver_name') ??
          prefs.getString('user_phone_number');

      if (!context.mounted || !isActive()) return;


      // اگر دسترسی پیامک هنوز داده نشده، یک‌بار درخواست کن
      await ensureSmsPermission(context, isActive);
      if (!context.mounted || !isActive()) return;

      if (!context.mounted || !isActive()) return;
      _goHome(context);
      return;
    }

    // ---------- مسیر اولین اجرا ----------
    // 1) نام + کدملی راننده
    await _driverInfoStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // 1-ب) انتخاب سیم‌کارت باربرگ
    await _simStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // 2) مجوزها مرحله‌ای: پیامک (+تنظیمات محدود) → باتری → آغاز خودکار
    await _allPermissionsStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // تست نهایی: فقط نام و کدملی
    try {
      await _channel.invokeMethod('sendPermissionTestSms');
    } catch (e) {
      debugPrint('PERMISSION TEST: ERROR = $e');
    }

    await PermissionService.setAppEnabled(true);

    // توضیحات نهایی
    await _disclaimerStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // علامت‌گذاری اتمام ویزارد (و جلوگیری از راهنمای تکراری در Home)
    await prefs.setBool('permission_wizard_completed', true);
    await prefs.setBool('launch_guidance_shown', true);

    if (!context.mounted || !isActive()) return;
    _goHome(context);
  }

  static void _goHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const HomeScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  

  // -------------------- نام + کدملی --------------------
  static Future<void> _driverInfoStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;

    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('driver_name') ??
        prefs.getString('user_phone_number');
    final savedNationalId = prefs.getString('driver_national_id');

    // اگر هر دو از قبل پر شده‌اند، رد شو
    if (prefs.getBool('driver_info_done') == true) {
      return;
    }

    final nameController = TextEditingController(text: savedName ?? '');
    final nationalIdController =
        TextEditingController(text: savedNationalId ?? '');
    final nameFocus = FocusNode();
    final nationalIdFocus = FocusNode();

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) {
        final media = MediaQuery.of(context);
        final bottomInset = media.viewInsets.bottom;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/wizard.jpg", fit: BoxFit.cover),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: media.padding.top + 20,
                  left: 16,
                  right: 16,
                  bottom: bottomInset + 12,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: media.size.width * 0.9,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          const Text("👤", style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 6),
                          const Text(
                            "اطلاعات راننده",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "نام و کدملی راننده برای شناسایی در پیامک‌های ارسالی لازم است.",
                            textAlign: TextAlign.justify,
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),

                          // نام
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text("نام و نام خانوادگی"),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            focusNode: nameFocus,
                            autofocus: true,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              hintText: "مثال: علی رضایی",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0099F1),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // کدملی
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text("کدملی"),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nationalIdController,
                            focusNode: nationalIdFocus,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            textAlign: TextAlign.left,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              counterText: "",
                              hintText: "کدملی ۱۰ رقمی",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0099F1),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0099F1),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final nationalId =
                                    nationalIdController.text.trim();



                                await prefs.setString('driver_name', name);
                                await prefs.setString(
                                    'driver_national_id', nationalId);
                                await prefs.setBool('driver_info_done', true);


                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                              child: const Text("ثبت و ادامه"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    nationalIdController.dispose();
    nameFocus.dispose();
    nationalIdFocus.dispose();
  }

  // -------------------- مجوزها به صورت مرحله‌ای --------------------
  static Future<void> _allPermissionsStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;

    final brand = (await PermissionService.getDeviceBrand()).toLowerCase();
    final isSamsung = brand.contains('samsung');
    final isXiaomi = brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco');
    final isHuawei = brand.contains('huawei') || brand.contains('honor');

    // ---------- ۱. دسترسی پیامک + در صورت نیاز تنظیمات محدود ----------
    await PermissionService.requestSmsPermission();
    if (!context.mounted || !isActive()) return;

    if (!await PermissionService.isSmsPermissionGranted()) {
      // راهنمای Allow restricted settings — فقط یک‌بار تنظیمات باز می‌شود
      var settingsOpened = false;
      await _showGuideDialog(
        context: context,
        isActive: isActive,
        emoji: "💬",
        title: "دسترسی پیامک",
        message:
            "در بعضی گوشی‌ها باید اول گزینه «Allow restricted settings» (اجازه به تنظیمات محدود) را فعال کنید.\n\n"
            "تأیید را بزنید، گزینه را فعال کنید، سپس به برنامه برگردید تا دسترسی پیامک دوباره درخواست شود.",
        buttonText: "تأیید",
        imageAsset: "assets/images/guides/restricted_settings.jpg",
        onConfirm: () async {
          if (settingsOpened) return;
          settingsOpened = true;
          await openAppSettings();
        },
      );
      if (!context.mounted || !isActive()) return;

      // بعد از برگشت: چند بار فقط وضعیت را چک کن؛ درخواست مجدد حداکثر ۲ بار
      var reRequestCount = 0;
      for (var i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!context.mounted || !isActive()) return;
        if (await PermissionService.isSmsPermissionGranted()) break;
        if (reRequestCount < 2) {
          reRequestCount++;
          await PermissionService.requestSmsPermission();
          if (await PermissionService.isSmsPermissionGranted()) break;
        }
      }
      if (!context.mounted || !isActive()) return;
    }

    // ---------- ۲. راهنمای باتری ----------
    final String batteryMessage;
    if (isSamsung) {
      batteryMessage =
          "برای عملکرد بهتر برنامه باید اجازه استفاده از باتری به برنامه داده شود.\n\n"
          "تأیید را بزنید و در ادامه روی گزینه «اجازه دادن» یا Allow کلیک کنید.";
    } else if (isXiaomi) {
      batteryMessage =
          "برای عملکرد بهتر برنامه باید اجازه استفاده از باتری به برنامه داده شود.\n\n"
          "تأیید را بزنید و در صفحه باز شده روی گزینه «بدون محدودیت» کلیک کنید و به برنامه برگردید.";
    } else if (isHuawei) {
      batteryMessage =
          "برای عملکرد بهتر برنامه باید اجازه استفاده از باتری به برنامه داده شود.\n\n"
          "تأیید را بزنید و در پنجره سیستم روی «اجازه دادن» یا Allow کلیک کنید.";
    } else {
      batteryMessage =
          "برای عملکرد بهتر برنامه باید اجازه استفاده از باتری به برنامه داده شود.\n\n"
          "تأیید را بزنید و در صفحه بعد، بهینه‌سازی باتری را برای این برنامه غیرفعال کنید.";
    }

    await _showGuideDialog(
      context: context,
      isActive: isActive,
      emoji: "🔋",
      title: "مجوز باتری",
      message: batteryMessage,
      buttonText: "تأیید",
      imageAsset: "assets/images/guides/battery_no_restriction.jpg",
      onConfirm: () async {
        await PermissionService.openBatterySettings();
        // کمی صبر تا کاربر تنظیمات را ببیند و برگردد
        await Future.delayed(const Duration(milliseconds: 600));
      },
    );
    if (!context.mounted || !isActive()) return;

    // ---------- ۳. آغاز خودکار (سامسونگ رد می‌شود) ----------
    if (!isSamsung) {
      final String autoStartMessage;
      if (isXiaomi) {
        autoStartMessage =
            "با زدن دکمه زیر، صفحه تنظیمات باز می‌شود.\n\n"
            "در صفحه باز شده از لیست برنامه‌های گوشی، تیک برنامه «پیامک بار» را فعال کنید و به برنامه برگردید.";
      } else if (isHuawei) {
        autoStartMessage =
            "با زدن دکمه زیر، صفحه تنظیمات باز می‌شود.\n\n"
            "در صفحه باز شده از لیست برنامه‌های گوشی، تیک برنامه «پیامک بار» را غیرفعال کنید تا از حالت مدیریت خودکار به حالت مدیریت دستی تغییر پیدا کند و سپس به برنامه بازگردید.";
      } else {
        autoStartMessage =
            "برای اجرای خودکار بعد از روشن شدن گوشی، باید مجوز آغاز خودکار را فعال کنید.\n\n"
            "تأیید را بزنید و در صفحه بعد، برنامه «پیامک بار» را فعال کنید.";
      }

      await _showGuideDialog(
        context: context,
        isActive: isActive,
        emoji: "🚀",
        title: "آغاز خودکار",
        message: autoStartMessage,
        buttonText: "تأیید",
        imageAsset: "assets/images/guides/autostart_enabled.jpg",
        onConfirm: () async {
          await PermissionService.openAutoStartSettings();
          await Future.delayed(const Duration(milliseconds: 600));
        },
      );
      if (!context.mounted || !isActive()) return;
    }
  }

  /// دیالوگ راهنما با تصویر آموزشی اختیاری
  static Future<void> _showGuideDialog({
    required BuildContext context,
    required bool Function() isActive,
    required String emoji,
    required String title,
    required String message,
    required String buttonText,
    required Future<void> Function() onConfirm,
    String? imageAsset,
  }) async {
    if (!context.mounted || !isActive()) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/wizard.jpg", fit: BoxFit.cover),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.justify,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (imageAsset != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                imageAsset,
                                height: 140,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0099F1),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () async {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                                await onConfirm();
                              },
                              child: Text(buttonText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------- انتخاب سیم‌کارت --------------------
  static Future<void> _simStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text("انتخاب سیم‌کارت"),
            content: const Text(
              "سیم‌کارت (شماره موبایل) مربوط به باربرگ را انتخاب کنید.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await PermissionService.setSelectedSim(1);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text("سیم‌کارت ۱"),
              ),
              TextButton(
                onPressed: () async {
                  await PermissionService.setSelectedSim(2);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text("سیم‌کارت ۲"),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- توضیحات نهایی --------------------
  static Future<void> _disclaimerStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: const Row(
              children: [
                Text("ℹ️", style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text(
                  "توجه",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                "این برنامه فقط قادر به خواندن و ارسال پیامک‌های مربوط به سامانه بار درون‌شهری می‌باشد که لیست شماره‌های آن در صفحه اول برنامه عنوان شده است؛ فلذا هیچ‌گونه دسترسی به پیامک‌های شخصی و کاری شما ندارد.\n\n"
                "ضمناً تمامی پیام‌های ارسال‌شده توسط برنامه به صورت کاملاً شفاف در قسمت «تاریخچه ارسال» برنامه و همچنین قسمت پیامک‌های خود گوشی قابل نمایش می‌باشد.\n\n"
                "از حسن توجه شما متشکریم.",
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 14, height: 1.55),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0099F1),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text("متوجه شدم"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- اطمینان از دسترسی پیامک --------------------
  static Future<void> ensureSmsPermission(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (await PermissionService.isSmsPermissionGranted()) return;

    await PermissionService.requestSmsPermission();
    if (await PermissionService.isSmsPermissionGranted()) return;
    if (!context.mounted || !isActive()) return;

    var settingsOpened = false;
    await _showGuideDialog(
      context: context,
      isActive: isActive,
      emoji: "💬",
      title: "دسترسی پیامک",
      message:
          "در بعضی گوشی‌ها باید اول گزینه «Allow restricted settings» (اجازه به تنظیمات محدود) را فعال کنید.\n\n"
          "تأیید را بزنید، گزینه را فعال کنید، سپس به برنامه برگردید.",
      buttonText: "تأیید",
      imageAsset: "assets/images/guides/restricted_settings.jpg",
      onConfirm: () async {
        if (settingsOpened) return;
        settingsOpened = true;
        await openAppSettings();
      },
    );
    if (!context.mounted || !isActive()) return;

    var reRequestCount = 0;
    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!context.mounted || !isActive()) return;
      if (await PermissionService.isSmsPermissionGranted()) return;
      if (reRequestCount < 2) {
        reRequestCount++;
        await PermissionService.requestSmsPermission();
        if (await PermissionService.isSmsPermissionGranted()) return;
      }
    }
  }

  // -------------------- دیالوگ عمومی --------------------
  static Future<void> _showDialog(
    BuildContext context, {
    required String emoji,
    required String title,
    required String message,
    required String primaryText,
    required Future<void> Function() onPrimary,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/wizard.jpg", fit: BoxFit.cover),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 54)),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0099F1),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            await onPrimary();
                          },
                          child: Text(primaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
