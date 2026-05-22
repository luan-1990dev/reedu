import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart'; // Caminho corrigido

// FUNÇÃO TOP-LEVEL PARA MENSAGENS EM SEGUNDO PLANO (Obrigatório)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Mensagem recebida em segundo plano: ${message.notification?.title}");
}

void main() async {
  // 1. Garante a inicialização dos Widgets do Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa a formatação de datas para o Calendário
  await initializeDateFormatting('pt_BR', null);

  // 3. Modo Imersivo Total e Estilo do Sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  bool firebaseInitialized = false;

  try {
    // 4. Inicializa o Firebase
    await Firebase.initializeApp();
    firebaseInitialized = true;

    // 5. Configura o Crashlytics para capturar erros automaticamente
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Captura erros assíncronos fora do contexto do Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // 6. Configura Push Notifications em segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 7. Inicializa os serviços de Notificação
    final notificationService = NotificationService();
    await notificationService.initNotification();
    await notificationService.setupPushNotifications();

  } catch (e) {
    debugPrint("ERRO Crítico na inicialização: $e");
  }

  runApp(MyApp(isFirebaseReady: firebaseInitialized));
}

// Rotina de manutenção: Limpa histórico e agenda alarmes
Future<void> _setupNotificationsSafe() async {
  try {
    final notificationService = NotificationService();
    final DatabaseService db = DatabaseService();

    // Limpa alertas de dias anteriores (Regra das 00:00)
    await db.clearOldNotifications();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        final double waterTarget = (data['waterTarget'] ?? 4.0).toDouble();

        // Agenda lembretes de água
        await notificationService.scheduleWaterReminders(waterTarget);

        // Agenda lembretes de refeições
        if (data.containsKey('meal_schedules')) {
          final List<dynamic> schedules = data['meal_schedules'];
          await notificationService.scheduleCustomNotifications(
              List<Map<String, dynamic>>.from(schedules)
          );
        }
      } else {
        await notificationService.scheduleWaterReminders(4.0);
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
              return const HomePage();
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}