import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalahoo_app/widgets/header_background.dart';
import 'package:dalahoo_app/features/settings/settings_screen.dart';
import 'package:dalahoo_app/features/history/history_screen.dart';
import 'package:dalahoo_app/features/config/remote_config_service.dart';
import 'package:dalahoo_app/features/permissions/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color backgroundColor = Color(0xFFF2F3FA);
  late AnimationController controller;
  late Animation<double> card1;
  late Animation<double> card2;
  late Animation<double> card3;

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nationalIdController = TextEditingController();

  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode nationalIdFocusNode = FocusNode();

  String _senderText = RemoteConfigService.defaultSenders.map((s) => s.replaceFirst(RegExp(r'^98'), '')).join('  ·  ');
  int _selectedSim = 1;

  Widget _simButton(int slot) {
    final selected = _selectedSim == slot;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF0099F1) : Colors.white,
        foregroundColor: selected ? Colors.white : Colors.black87,
      ),
      onPressed: () async {
        await PermissionService.setSelectedSim(slot);
        if (!mounted) return;
        setState(() => _selectedSim = slot);
      },
      child: Text("سیم‌کارت $slot"),
    );
  }

  bool isEditingPhone = false;
  bool isPhoneSaved = false;

  bool isEditingNationalId = false;
  bool isNationalIdSaved = false;

  @override
  void initState() {
    super.initState();

    loadSenderNumbers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkBatteryAndAutostart();
    });

    controller = AnimationController(
      vsync: this,
      // انیمیشن کوتاه‌تر برای گوشی‌های ضعیف
      duration: const Duration(milliseconds: 450),
    );

    card1 = Tween(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    card2 = Tween(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    card3 = Tween(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    loadPhoneNumber();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.forward();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    phoneFocusNode.dispose();
    nationalIdFocusNode.dispose();
    phoneController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

  Widget animatedCard(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, animation.value),
          child: child,
        );
      },
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    );
  }

  Future<void> _checkBatteryAndAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('launch_guidance_shown') == true) return;

    final optimized = await PermissionService.isBatteryOptimized();
    if (!mounted) return;
    if (optimized) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text("بهینه‌سازی باتری"),
            content: const Text(
              "روی دکمه‌ی فعال‌سازی بزن. در صفحه‌ی باز شده، حالت مصرف باتری را روی «بدون محدودیت» بگذار.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await PermissionService.openBatterySettings();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text("فعال‌سازی"),
              ),
            ],
          ),
        ),
      );
    }

    // آغاز خودکار دیگر اینجا نشان داده نمی‌شود (در ویزارد اولیه انجام شده)
    await prefs.setBool('launch_guidance_shown', true);
  }

  Future<void> loadSenderNumbers() async {
    final senders = await RemoteConfigService.loadSenders();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final sim = prefs.getInt('selectedSim') ?? 1;
    if (!mounted) return;
    setState(() {
      // نمایش بدون پیش‌شماره ۹۸
      _senderText = senders
          .map((s) {
            var n = s.replaceAll(RegExp(r'[^0-9]'), '');
            if (n.startsWith('98') && n.length > 10) n = n.substring(2);
            if (n.startsWith('0') && n.length > 10) n = n.substring(1);
            return n;
          })
          .join('  ·  ');
      _selectedSim = sim;
    });
  }

  Future<void> loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();

    // Prefer new key, fallback to old for compatibility
    final savedName = prefs.getString('driver_name') ??
        prefs.getString('user_phone_number');
    final savedNationalId = prefs.getString('driver_national_id');

    if (!mounted) return;

    setState(() {
      if (savedName != null && savedName.isNotEmpty) {
        phoneController.text = savedName;
        isPhoneSaved = true;
      }

      if (savedNationalId != null && savedNationalId.isNotEmpty) {
        nationalIdController.text = savedNationalId;
        isNationalIdSaved = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        title: const Text("پیامک بار"),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          const HeaderBackground(height: 130),

          Column(
            children: [
              const SizedBox(height: 130),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        animatedCard(
                          card1,
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: cardDecoration(),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "شماره‌های فرستنده:",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _senderText,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "شماره گیرنده",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        "5000200050",
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),

                                  
                                  

                                  ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        animatedCard(
                          card2,
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: cardDecoration(),
                            child: Column(
                              children: [
                                const Text("نام و نام خانوادگی راننده"),

                                const SizedBox(height: 12),

                                TextField(
                                  controller: phoneController,
                                  focusNode: phoneFocusNode,
                                  enabled: isEditingPhone,
                                  keyboardType: TextInputType.name,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0099F1),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,

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

                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),

                                    hintText: "مثال: علی رضایی",
                                  ),
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0099F1),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      if (!isEditingPhone) {
                                        setState(() {
                                          isEditingPhone = true;
                                        });

                                        Future.delayed(
                                          const Duration(milliseconds: 100),
                                          () {
                                            phoneFocusNode.requestFocus();
                                          },
                                        );

                                        return;
                                      }

                                      final name = phoneController.text.trim();


                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        "driver_name",
                                        name,
                                      );

                                      if (!mounted) return;

                                      setState(() {
                                        isEditingPhone = false;
                                        isPhoneSaved = true;
                                      });

                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text("نام راننده ذخیره شد"),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      isPhoneSaved
                                          ? "ویرایش نام راننده"
                                          : "ثبت نام راننده",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // کدملی راننده
                        animatedCard(
                          card2,
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: cardDecoration(),
                            child: Column(
                              children: [
                                const Text("کدملی راننده"),

                                const SizedBox(height: 12),

                                TextField(
                                  controller: nationalIdController,
                                  focusNode: nationalIdFocusNode,
                                  enabled: isEditingNationalId,
                                  keyboardType: TextInputType.number,
                                  maxLength: 10,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0099F1),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    counterText: "",
                                    hintText: "کدملی ۱۰ رقمی",
                                  ),
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0099F1),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      if (!isEditingNationalId) {
                                        setState(() {
                                          isEditingNationalId = true;
                                        });

                                        Future.delayed(
                                          const Duration(milliseconds: 100),
                                          () {
                                            nationalIdFocusNode.requestFocus();
                                          },
                                        );

                                        return;
                                      }

                                      final nationalId =
                                          nationalIdController.text.trim();


                                      final messenger =
                                          ScaffoldMessenger.of(context);

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        "driver_national_id",
                                        nationalId,
                                      );

                                      if (!mounted) return;

                                      setState(() {
                                        isEditingNationalId = false;
                                        isNationalIdSaved = true;
                                      });

                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text("کدملی ذخیره شد"),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      isNationalIdSaved
                                          ? "ویرایش کدملی"
                                          : "ثبت کدملی",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: cardDecoration(),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "سیم‌کارت باربرگ",
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _simButton(1)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _simButton(2)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        animatedCard(
                          card3,
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: cardDecoration(),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0099F1),
                                      side: const BorderSide(
                                        color: Color(0xFF0099F1),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        _softTransition(const HistoryScreen()),
                                      );
                                    },
                                    icon: const Icon(Icons.history_rounded),
                                    label: const Text("تاریخچه ارسال"),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "برای عملکرد صحیح برنامه «تنظیمات دسترسی» ضروری است",
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0099F1),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        _softTransition(const SettingsScreen()),
                                      );
                                    },
                                    child: const Text("تنظیمات دسترسی"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

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
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("در حال بررسی آپدیت..."),
                                ),
                              );
                              final msg =
                                  await RemoteConfigService.checkAndUpdate();
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            },
                            child: const Text("بروزرسانی برنامه"),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _NavButton({required this.icon, required this.onTap, this.iconColor});

  static const Color backgroundColor = Color(0xFFF2F3FA);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(icon, size: 24, color: iconColor ?? Colors.black),
      ),
    );
  }
}

PageRouteBuilder _softTransition(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, animation, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final slide = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

      final fade = Tween(begin: 0.0, end: 1.0).animate(animation);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
