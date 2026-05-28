import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/notification_history_page.dart';

import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Mensagem recebida em segundo plano: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // 3. Modo Imersivo Total e Estilo do Sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  bool firebaseInitialized = false;

  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final notificationService = NotificationService();
    await notificationService.initNotification();
    await notificationService.setupPushNotifications();

  } catch (e) {
    debugPrint("ERRO Crítico na inicialização: $e");
  }

  runApp(MyApp(isFirebaseReady: firebaseInitialized));
}

Future<void> _setupNotificationsSafe() async {
  try {
    final notificationService = NotificationService();
    final DatabaseService db = DatabaseService();
    await db.clearOldNotifications();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        final double waterTarget = (data['waterTarget'] ?? 4.0).toDouble();

        final List<String> waterIntervals = List<String>.from(data['waterIntervals'] ?? ['07:00-12:00', '13:00-15:00', '15:00-18:30', '18:30-22:00']);
        await notificationService.scheduleWaterReminders(waterTarget, waterIntervals);

        if (data.containsKey('meal_schedules')) {
          final List<dynamic> schedules = data['meal_schedules'];
          await notificationService.scheduleCustomNotifications(
              List<Map<String, dynamic>>.from(schedules)
          );
        }
      } else {
        await notificationService.scheduleWaterReminders(4.0, ['07:00-12:00', '13:00-15:00', '15:00-18:30', '18:30-22:00']);
      }
    }
  } catch (e) {
    debugPrint("Aviso: Falha ao carregar agendamentos: $e");
  }
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  const MyApp({super.key, required this.isFirebaseReady});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isFirebaseReady) _setupNotificationsSafe();
    });


    return GestureDetector(
      onTap: () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      child: MaterialApp(
        title: 'Reedu',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
          routes: {    '/notifications': (context) => const NotificationHistoryPage(),},

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1967D2)),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: !isFirebaseReady
            ? const Scaffold(body: Center(child: Text("Falha ao conectar com o servidor.")))
            : StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasData && snapshot.data != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _setupNotificationsSafe();
              });
              return const HomePage();
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}