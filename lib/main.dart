import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dalahoo_app/features/home/home_screen.dart';
import 'package:dalahoo_app/features/settings/settings_screen.dart';
import 'package:dalahoo_app/features/splash/splash_screen.dart';
import 'package:dalahoo_app/features/config/remote_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // حداکثر هر ۲۴ ساعت؛ مسیر اصلی اپ را مسدود نمی‌کند
  RemoteConfigService.refresh();

  runApp(const DalahooApp());
}

class DalahooApp extends StatefulWidget {
  const DalahooApp({super.key});

  @override
  State<DalahooApp> createState() => _DalahooAppState();
}

class _DalahooAppState extends State<DalahooApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // برگشت به اپ: فقط اگر ۲۴ ساعت گذشته باشد دوباره می‌خواند
    if (state == AppLifecycleState.resumed) {
      RemoteConfigService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'پیامک بار',
      theme: ThemeData(
        fontFamily: 'Yekan',
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      routes: {
        "/settings": (context) => const SettingsScreen(),
        "/home": (context) => const HomeScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
