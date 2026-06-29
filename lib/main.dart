import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/password/change_password_screen.dart';
import 'screens/sos/home_screen.dart';
import 'screens/sos/background_service.dart'; 
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/confirmed_screen.dart';
import 'screens/auth/how_screen.dart';
import 'screens/auth/permissions_screen.dart';
import 'screens/sos/safe_screen.dart';
import 'screens/trust_contacts/add_trust_contact_screen.dart';
import 'screens/trust_contacts/add_contact_screen.dart';
import 'screens/trust_contacts/contact_added_screen.dart';
import 'screens/auth/password/forgot_password_screen.dart';
import 'screens/auth/password/verification_screen.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  WidgetsBinding.instance.addObserver(AppLifecycleReactor());

  await _setupNotifications();
  await _startServiceSafely(); 
  runApp(const VoxGuardApp());
}

class AppLifecycleReactor extends WidgetsBindingObserver {
@override
void didChangeAppLifecycleState(AppLifecycleState state) async {
  if (state == AppLifecycleState.resumed) {
    final prefs = await SharedPreferences.getInstance();
    
    bool isSosActive = prefs.getBool('sos_active') ?? false;
    int? sosId = activeSosIdInMemory ?? prefs.getInt('active_sos_id');

    if (isSosActive && sosId != null) {
      final currentRoute = ModalRoute.of(navigatorKey.currentContext!)?.settings.name;
      
      if (currentRoute != '/safe') {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/safe',
          (route) => false,
          arguments: sosId,
        );
      }
    }
  }
}
}

Future<void> _setupNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
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

class VoxGuardApp extends StatelessWidget {
  const VoxGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
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
        '/verification': (context) => const VerificationScreen(),
        '/home': (context) => const HomeScreen(),
        '/change_password': (context) => const ChangePasswordScreen(),
        '/safe': (context) => const SafeHomeScreen(), 
      },
    );
  }
}