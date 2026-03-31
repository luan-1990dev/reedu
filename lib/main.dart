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
  
  // MODO IMERSIVO TOTAL (Edge-to-Edge)
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
    await Firebase.initializeApp();
    firebaseInitialized = true;
    _initNotifications();
  } catch (e) {
    debugPrint("ERRO CRÍTICO na inicialização: \$e");
  }
  
  runApp(MyApp(isFirebaseReady: firebaseInitialized));
}

Future<void> _initNotifications() async {
  try {
    final notificationService = NotificationService();
    await notificationService.initNotification();
    
    // 1. Agenda lembretes de água (Independente de horários de comida)
    await notificationService.scheduleWaterReminders();
    
    // 2. Busca os horários salvos para agendar as notificações de refeição
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('meal_schedules')) {
        final List<dynamic> schedules = doc.data()!['meal_schedules'];
        await notificationService.scheduleCustomNotifications(List<Map<String, dynamic>>.from(schedules));
      }
    }
  } catch (e) {
    debugPrint("Erro ao configurar notificações: \$e");
  }
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  const MyApp({super.key, required this.isFirebaseReady});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: MaterialApp(
        title: 'Reedu',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1967D2)),
          useMaterial3: true,
        ),
        home: !isFirebaseReady 
            ? const Scaffold(body: Center(child: Text("Erro ao carregar o Firebase.")))
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
