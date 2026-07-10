import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/auth/password/change_password_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/confirmed_screen.dart';
import 'screens/auth/how_screen.dart';
import 'screens/auth/permissions_screen.dart';
import 'screens/trust_contacts/add_trust_contact_screen.dart';
import 'screens/trust_contacts/add_contact_screen.dart';
import 'screens/trust_contacts/contact_added_screen.dart';
import 'screens/auth/password/forgot_password_screen.dart';
import 'screens/auth/password/verification_screen.dart';
import 'screens/sos/home_screen.dart';
import 'screens/sos/safe_screen.dart';
import 'screens/sos/background_service.dart';
import 'screens/emergency_screen.dart';
import 'config/api_config.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Auto-discover the Laravel backend server on the local network subnet
  await ApiConfig.autoDiscoverServer();

  WidgetsBinding.instance.addObserver(AppLifecycleReactor());

  // Run these in the background to avoid blocking the first frame render
  _setupNotifications();
  _startServiceSafely();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const VoxGuardApp(),
    ),
  );
}

class AppLifecycleReactor extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        final prefs = await SharedPreferences.getInstance();
        bool isSosActive = prefs.getBool('sos_active') ?? false;
        int? sosId = activeSosIdInMemory ?? prefs.getInt('active_sos_id');

        if (isSosActive && sosId != null) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute != '/safe') {
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/safe',
                (route) => false,
                arguments: sosId,
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error in AppLifecycleReactor: $e");
      }
    }
  }
}

Future<void> _setupNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint("Notification clicked: ${response.payload}");
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'voxguard_emergency',
    'VoxGuard Emergency Service',
    description: 'This channel is used for vital personal safety features.',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _startServiceSafely() async {
  final service = FlutterBackgroundService();
  
  if (!(await service.isRunning())) {
    final status = await Permission.microphone.status;
    final locStatus = await Permission.locationAlways.status;

    if (status.isGranted && locStatus.isGranted) {
      await initializeBackgroundService();
    }
  }
}

class VoxGuardApp extends StatefulWidget {
  const VoxGuardApp({super.key});

  @override
  State<VoxGuardApp> createState() => _VoxGuardAppState();
}

class _VoxGuardAppState extends State<VoxGuardApp> {
  static const _panicChannel = MethodChannel('com.example.vox_guard/panic');

  @override
  void initState() {
    super.initState();
    _panicChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerPanicSos') {
        _navigateToEmergency();
      }
    });
    _checkPendingTrigger();
  }

  void _navigateToEmergency() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/emergency',
      (route) => false,
    );
  }

  Future<void> _checkPendingTrigger() async {
    try {
      final bool hasPending = await _panicChannel.invokeMethod('checkPendingTrigger') ?? false;
      if (hasPending) {
        _navigateToEmergency();
      }
    } catch (e) {
      debugPrint("Error checking pending trigger: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/confirmed': (context) => const ConfirmedScreen(),
        '/how_safe': (context) => const HowWeKeepSafeScreen(),
        '/permissions': (context) => const PermissionsScreen(),
        '/trust_contacts': (context) => const AddTrustedContactsScreen(),
        '/add_contact': (context) => const AddContactScreen(),
        '/contact_added': (context) => const ContactAddedScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/verification': (context) => const VerificationScreen(emailOrPhone: ''),
        '/home': (context) => const HomeScreen(),
        '/change_password': (context) => const ChangePasswordScreen(emailOrPhone: '', code: ''),
        '/safe': (context) {
          final sosId = ModalRoute.of(context)?.settings.arguments as int?;
          return SafeHomeScreen(sosId: sosId);
        },
        '/emergency': (context) => const EmergencyScreen(),
      },
    );
  }
}