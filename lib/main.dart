import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'services/notification_service.dart';
import '../services/database_service.dart'; // Garanta que este caminho para o DatabaseService esteja correto
import 'package:intl/date_symbol_data_local.dart';

// FUNÇÃO TOP-LEVEL PARA MENSAGENS EM SEGUNDO PLANO (Obrigatório)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Mensagem recebida em segundo plano: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a formatação de datas para português do Brasil
  await initializeDateFormatting('pt_BR', null);

  // MODO IMERSIVO TOTAL E ESTILO DO SISTEMA
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
    // 1. INICIALIZA O FIREBASE
    await Firebase.initializeApp();
    firebaseInitialized = true;

    // 2. CONFIGURA O HANDLER DE SEGUNDO PLANO
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. INICIALIZA AS NOTIFICAÇÕES LOCAIS E PUSH
    final notificationService = NotificationService();
    await notificationService.initNotification();
    await notificationService.setupPushNotifications();

  } catch (e) {
    debugPrint("ERRO Crítico na inicialização: $e");
  }

  runApp(MyApp(isFirebaseReady: firebaseInitialized));
}

// CORREÇÃO: Função unificada, limpa e com escopo corrigido
Future<void> _setupNotificationsSafe() async {
  try {
    final notificationService = NotificationService();
    await notificationService.initNotification();

    // Executa a manutenção e limpeza de dados antigos de forma limpa
    final DatabaseService db = DatabaseService();
    await db.clearOldNotifications();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        final double waterTarget = (data['waterTarget'] ?? 4.0).toDouble();

        // Agenda as rotinas do usuário
        await notificationService.scheduleWaterReminders(waterTarget);

        if (data.containsKey('meal_schedules')) {
          final List<dynamic> schedules = data['meal_schedules'];
          await notificationService.scheduleCustomNotifications(
              List<Map<String, dynamic>>.from(schedules)
          );
        }
      } else {
        // Fallback para usuários novos sem documento criado
        await notificationService.scheduleWaterReminders(4.0);
      }
    }
  } catch (e) {
    debugPrint("Aviso: Falha ao carregar agendamentos automáticos: $e");
  }
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  const MyApp({super.key, required this.isFirebaseReady});

  @override
  Widget build(BuildContext context) {
    // Dispara a configuração de notificações após o primeiro frame para não travar a abertura
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
            if (snapshot.hasData) {
              return const HomePage();
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}
