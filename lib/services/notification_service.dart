import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz_data.initializeTimeZones();

    try {
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }


    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('launcher_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: androidSettings);

    await notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? actionId = response.actionId;
        final String? payload = response.payload;

        if (actionId == 'water_ok' && payload != null && payload.contains('|')) {
          try {
            final parts = payload.split('|');
            final String period = parts[0];
            final double amount = double.tryParse(parts[1]) ?? 0.0;

            final DatabaseService db = DatabaseService();
            if (FirebaseAuth.instance.currentUser != null) {
              await db.addWaterConsumption(period, amount);
            }
          } catch (e) {
            debugPrint("Erro ano clique da notificação $e");
          }
        }

        if (actionId == 'dismiss_alarm' || actionId == 'water_ok' || actionId == 'water_fail') {
          notificationsPlugin.cancel(id: response.id!);
        }
      },
    );

    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel waterChannel = AndroidNotificationChannel(
      'reedu_water_cycle',
      'Ciclos de Hidratação',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(waterChannel);
  }

  Future<void> _saveToHistory({required String id, required String title, required String body, required String type}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications_history')
        .doc(id)
        .set({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'isRead': false,
    }, SetOptions(merge: true));
  }

  Future<void> requestAllPermissions(BuildContext context) async {
    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await Permission.notification.request();
    if (androidPlugin != null) {
      await androidPlugin.requestExactAlarmsPermission();
    }
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        notificationsPlugin.show(
          id: message.hashCode,
          title: message.notification!.title,
          body: message.notification!.body,
          notificationDetails: _notificationDetails("Novidades"),
        );
      }
    });
  }

  Future<void> scheduleCustomNotifications(List<Map<String, dynamic>> schedules) async {
    for (int i = 1; i < 100; i++) await notificationsPlugin.cancel(id: i);

    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var meal in schedules) {
      String title = 'Refeição Reedu 🍽️';
      String body = 'Está na hora do seu ${meal['name']}';

      await notificationsPlugin.zonedSchedule(
        id: meal['id'] as int,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfTime(meal['hour'] as int, meal['minute'] as int),
        notificationDetails: _notificationDetails('Alarmes de Refeição'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      _saveToHistory(
          id: "refeicao_${meal['id']}_$hojeStr",
          title: title,
          body: body,
          type: 'Refeição'
      );
    }
  }

  Future<void> scheduleDailySummary({
    required double waterTotal,
    required Map mealChecks,
    required Map<int, bool> monthlyHistory,
  }) async {
    String waterStatus = waterTotal <= 1.0 ? "Extremamente Crítico ⚠️" :
    waterTotal <= 2.0 ? "Crítico 🟠" :
    waterTotal <= 3.0 ? "Aceitável 🔵" : "Excelente ✅";

    String check(String key) => mealChecks[key] != null ? "✅" : "❌";
    String calendarGrid = _generateCalendarGrid(monthlyHistory);

    String mealSummary = "📅 Checklist de Refeições:\n"
        "☕ Café da manhã: ${check('cafe')}\n"
        "🥪 Lanche M: ${check('lanche_m')}\n"
        "🍲 Almoço: ${check('almoco')}\n"
        "🥪 Lanche T1: ${check('lanche_t1')}\n"
        "🥗 Lanche T2: ${check('lanche_t2')}\n"
        "🍽️ Jantar: ${check('jantar')}";

    String fullMessage = "Consumo de água: ${waterTotal.toStringAsFixed(1)}L ($waterStatus)\n\n"
        "$mealSummary\n\n"
        "📅 PROGRESSO NO MÊS:\n$calendarGrid\n"
        "Legenda: ✅ No Plano | ❌ Fora | ◽ Pendente";

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 8, 15, 0);

    await notificationsPlugin.zonedSchedule(
      id: 777,
      title: "Resumo do seu dia anterior 📊",
      body: "Consumo de água: ${waterTotal.toStringAsFixed(1)}L (Puxe p/ ver)",
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'reedu_summary_channel', 'Resumo Diário',
          importance: Importance.max, priority: Priority.high,
          styleInformation: BigTextStyleInformation(fullMessage),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _saveToHistory(
        id: "resumo_$hojeStr",
        title: "Resumo do seu dia anterior 📊",
        body: fullMessage,
        type: 'Resumo'
    );
  }

  Future<void> scheduleWaterReminders(double dailyTotal) async {
    for (int i = 200; i < 300; i++) await notificationsPlugin.cancel(id: i);

    double targetPerCycle = dailyTotal / 4;
    double amountPerReminder = targetPerCycle / 4;
    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final List<Map<String, dynamic>> schedule = [
      {'id': 201, 'h': 07, 'm': 00, 'type': 'start', 'period': '07:00 - 12:00', 'msg': 'Início do ciclo da manhã! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 202, 'h': 08, 'm': 00, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Hora de beber água!'},
      {'id': 203, 'h': 09, 'm': 00, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Não esqueça de se hidratar!'},
      {'id': 204, 'h': 10, 'm': 00, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Mais um pouco de água!'},
      {'id': 205, 'h': 11, 'm': 00, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Última hidratação antes do almoço!'},
      {'id': 206, 'h': 12, 'm': 00, 'type': 'end', 'period': '07:00 - 12:00', 'msg': 'Fim do ciclo da manhã.'},
      {'id': 207, 'h': 13, 'm': 00, 'type': 'start', 'period': '13:00 - 15:00', 'msg': 'Início do primeiro ciclo da tarde! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 208, 'h': 14, 'm': 00, 'type': 'ask', 'period': '13:00 - 15:00', 'msg': 'Não esqueça de se hidratar!'},
      {'id': 209, 'h': 15, 'm': 00, 'type': 'end', 'period': '13:00 - 15:00', 'msg': 'Fim do ciclo da tarde.'},
      {'id': 210, 'h': 16, 'm': 30, 'type': 'ask', 'period': '15:00 - 18:30', 'msg': 'Início do segundo ciclo da tarde! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 211, 'h': 17, 'm': 30, 'type': 'ask', 'period': '15:00 - 18:30', 'msg': 'Mais um copo de água!'},
      {'id': 212, 'h': 18, 'm': 30, 'type': 'end', 'period': '15:00 - 18:30', 'msg': 'Fim do ciclo da tarde.'},
      {'id': 213, 'h': 19, 'm': 00, 'type': 'ask', 'period': '18:30 - 22:00', 'msg': 'Início do ciclo da noite! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 214, 'h': 20, 'm': 00, 'type': 'ask', 'period': '18:30 - 22:00', 'msg': 'Não esqueça da água!'},
      {'id': 215, 'h': 21, 'm': 00, 'type': 'ask', 'period': '18:30 - 22:00', 'msg': 'Essa é a hidratação final!'},
      {'id': 216, 'h': 22, 'm': 00, 'type': 'end', 'period': '18:30 - 22:00', 'msg': 'Fim do ciclo da noite. Bom descanso!'},
    ];

    for (var alarm in schedule) {
      String title = 'Reedu - Água 💧';
      await notificationsPlugin.zonedSchedule(
        id: alarm['id'] as int,
        title: title,
        body: alarm['msg'],
        payload: "${alarm['period']}|$amountPerReminder",
        scheduledDate: _nextInstanceOfTime(alarm['h'] as int, alarm['m'] as int),
        notificationDetails: _buildWaterDetails(alarm['type'] as String),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      _saveToHistory(
          id: "agua_${alarm['id']}_$hojeStr",
          title: title,
          body: alarm['msg'],
          type: 'Água'
      );
    }
  }

  NotificationDetails _buildWaterDetails(String type) {
    List<AndroidNotificationAction>? actions;
    if (type == 'ask') {
      actions = [
        const AndroidNotificationAction('water_ok', 'BEBI ✅', showsUserInterface: true, cancelNotification: true),
        const AndroidNotificationAction('water_fail', 'PULAR ❌', showsUserInterface: true, cancelNotification: true),
      ];
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'reedu_water_cycle', 'Ciclos de Hidratação',
        importance: Importance.max, priority: Priority.high,
        actions: actions,
      ),
    );
  }

  NotificationDetails _notificationDetails(String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'reedu_precision_alerts', channelName,
        importance: Importance.max, priority: Priority.high,
      ),
    );
  }

  String _generateCalendarGrid(Map<int, bool> monthlyHistory) {
    final now = DateTime.now();
    final int lastDay = DateTime(now.year, now.month + 1, 0).day;
    String grid = "";
    for (int day = 1; day <= lastDay; day++) {
      if (monthlyHistory.containsKey(day)) {
        grid += monthlyHistory[day]! ? "✅" : "❌";
      } else {
        grid += (day < now.day) ? "◽" : (day == now.day) ? "🔵" : "⚪";
      }
      grid += (day % 7 == 0) ? "\n" : " ";
    }
    return grid;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> checkPendingNotifications(BuildContext context) async {
    final list = await notificationsPlugin.pendingNotificationRequests();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${list.length} alarmes ativos no sistema.')));
  }

  Future<void> cancelAllNotifications(BuildContext context) async {
    await notificationsPlugin.cancelAll();
  }

  Future<void> testDailySummaryNotification(BuildContext context) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    Map<int, bool> mockHistory = {1: true, 2: false, 3: true, now.day - 1: true};

    await scheduleDailySummary(
      waterTotal: 3.5,
      mealChecks: {'cafe': 'ok', 'almoco': 'ok', 'jantar': 'ok'},
      monthlyHistory: mockHistory,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumo agendado para amanhã às 08:15!')),
    );
  }
}