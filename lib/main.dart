import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/fake_call/incoming_fake_call_mom.dart';
import 'screens/fake_call/incoming_fake_call_dad.dart';
import 'screens/fake_call/incoming_fake_call_police.dart';

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
bool _isNotificationsInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Auto-discover the Laravel backend server on the local network subnet
  await ApiConfig.autoDiscoverServer();

  WidgetsBinding.instance.addObserver(AppLifecycleReactor());

  // Initialize notifications synchronously to prevent early background events from calling .show() before initialization completes
  await _setupNotifications();
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

void _handleFakeCallTrigger(Map<String, dynamic> data) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  // Prevent duplicate navigations if we are already on an incoming call screen
  bool isAlreadyOnCall = false;
  navigatorKey.currentState?.popUntil((route) {
    if (route.settings.name != null && route.settings.name!.contains('IncomingFakeCall')) {
      isAlreadyOnCall = true;
    }
    return true;
  });
  if (isAlreadyOnCall) return;

  String caller = data['caller'] ?? 'mom';
  String ringtone = data['ringtone'] ?? 'ringtone_default';
  String imgPath = data['imgPath'] ?? 'images/Woman.png';

  Widget target;
  if (caller == 'mom') {
    target = IncomingFakeCallMom(
      name: 'mom'.tr(),
      imagePath: imgPath,
      callerName: 'mom'.tr(),
      callTime: 'now'.tr(),
      ringtone: ringtone,
    );
  } else if (caller == 'dad') {
    target = IncomingFakeCallDad(
      name: 'dad'.tr(),
      imagePath: imgPath,
      callerName: 'dad'.tr(),
      callTime: 'now'.tr(),
      ringtone: ringtone,
    );
  } else {
    target = IncomingFakeCallPolice(
      name: 'police'.tr(),
      imagePath: imgPath,
      callerName: 'police'.tr(),
      callTime: 'now'.tr(),
      ringtone: ringtone,
    );
  }

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      settings: RouteSettings(name: 'IncomingFakeCall$caller'),
      builder: (context) => target,
    ),
  );
}

Future<void> _setupNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');

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
      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!);
          if (data['type'] == 'fake_call') {
            _handleFakeCallTrigger(Map<String, dynamic>.from(data));
          }
        } catch (e) {
          debugPrint("Error handling notification payload: $e");
        }
      }
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'voxguard_emergency',
    'VoxGuard Emergency Service',
    description: 'This channel is used for vital personal safety features.',
    importance: Importance.high,
  );

  const AndroidNotificationChannel fakeCallChannel = AndroidNotificationChannel(
    'voxguard_fake_call',
    'VoxGuard Fake Call',
    description: 'This channel is used to trigger scheduled fake calls.',
    importance: Importance.high,
  );

  final androidNotificationPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidNotificationPlugin != null) {
    await androidNotificationPlugin.createNotificationChannel(channel);
    await androidNotificationPlugin.createNotificationChannel(fakeCallChannel);
  }
  _isNotificationsInitialized = true;
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

    // Listen to background service event to trigger fake call on UI thread
    FlutterBackgroundService().on('triggerFakeCallNow').listen((event) async {
      if (!_isNotificationsInitialized) {
        debugPrint("Warning: triggerFakeCallNow received before notifications initialized");
        return;
      }
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        String caller = data['caller'] ?? 'mom';
        String ringtone = data['ringtone'] ?? 'ringtone_default';
        String imgPath = data['imgPath'] ?? 'images/Woman.png';

        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'voxguard_fake_call',
          'VoxGuard Fake Call',
          channelDescription: 'This channel is used to trigger scheduled fake calls.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        const NotificationDetails platformDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        String callerDisplayName = caller == 'mom' 
            ? 'أمي (Mom)' 
            : (caller == 'dad' ? 'أبي (Dad)' : 'الشرطة (Police)');

        try {
          await flutterLocalNotificationsPlugin.show(
            999,
            'إتصال وارد (Incoming Call)',
            'اضغط للرد على $callerDisplayName',
            platformDetails,
            payload: jsonEncode({
              'type': 'fake_call',
              'caller': caller,
              'ringtone': ringtone,
              'imgPath': imgPath,
            }),
          );
        } catch (e) {
          debugPrint("Failed to show local notification: $e");
        }

        // Trigger the fake call screen immediately so it functions even if notifications fail
        _handleFakeCallTrigger(data);
      }
    });

    _checkLaunchNotification();
  }

  Future<void> _checkLaunchNotification() async {
    try {
      final NotificationAppLaunchDetails? details =
          await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final payload = details?.notificationResponse?.payload;
        if (payload != null) {
          final data = jsonDecode(payload);
          if (data['type'] == 'fake_call') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleFakeCallTrigger(Map<String, dynamic>.from(data));
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking launch notification: $e");
    }
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