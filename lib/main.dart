import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MODO IMERSIVO TOTAL
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
    // Inicialização segura do Firebase
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint("ERRO na inicialização do Firebase: $e");
  }

  runApp(MyApp(isFirebaseReady: firebaseInitialized));
}

// Função atualizada para buscar a meta de água e agendar as notificações
Future<void> _setupNotificationsSafe() async {
  try {
    final notificationService = NotificationService();
    await notificationService.initNotification();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;

        // 1. Busca a meta de água (se não existir, assume 4.0 como padrão)
        final double waterTarget = (data['waterTarget'] ?? 4.0).toDouble();

        // 2. Agenda as notificações de água passando o parâmetro esperado
        await notificationService.scheduleWaterReminders(waterTarget);

        // 3. Agenda as notificações de refeição se existirem
        if (data.containsKey('meal_schedules')) {
          final List<dynamic> schedules = data['meal_schedules'];
          await notificationService.scheduleCustomNotifications(
              List<Map<String, dynamic>>.from(schedules)
          );
        }
      } else {
        // Caso o usuário ainda não tenha documento, agenda com o padrão de 4L
        await notificationService.scheduleWaterReminders(4.0);
      }
    }
  } catch (e) {
    debugPrint("Erro silencioso em notificações: $e");
  }
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  const MyApp({super.key, required this.isFirebaseReady});

  @override
  Widget build(BuildContext context) {
    // Dispara a configuração de notificações após o primeiro frame para não travar o splash
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
        ),
        home: !isFirebaseReady
            ? const Scaffold(body: Center(child: Text("Erro de conexão. Verifique a internet.")))
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