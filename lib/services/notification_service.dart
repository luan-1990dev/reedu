import 'dart:io';
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
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

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

        if (actionId == null || actionId.isEmpty) {
          if (payload == 'open_store') {
            _launchStore();
          } else {
            navigatorKey.currentState?.pushNamed('/notifications');
          }
        }

        if (payload != null && payload.contains('|')) {
          final parts = payload.split('|');
          final String period = parts[0];
          final double amount = double.tryParse(parts[1]) ?? 0.0;
          final String? historyId = parts.length > 2 ? parts[2] : null;

          final DatabaseService db = DatabaseService();

          if (actionId == 'water_ok') {
            if (FirebaseAuth.instance.currentUser != null) {
              await db.addWaterConsumption(period, amount);
              if (historyId != null) await _updateHistoryStatus(historyId, "Ok ✅");
              debugPrint("Reedu: Água somada e status atualizado.");
            }
          }
          else if (actionId == 'water_fail') {
            if (historyId != null) await _updateHistoryStatus(historyId, "Nok ❌");
          }
        }

        if (actionId != null || payload == 'open_store') {
          notificationsPlugin.cancel(id: response.id!);
        }
      },
    );

    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'reedu_water_cycle', 'Ciclos de Hidratação', importance: Importance.max, playSound: true, enableVibration: true,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'reedu_updates', 'Atualizações', importance: Importance.high,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'reedu_summary_channel', 'Resumo Diário', importance: Importance.max,
    ));
  }

  Future<void> _updateHistoryStatus(String docId, String status) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('notifications_history').doc(docId)
          .update({'status': status});
    } catch (e) {
      debugPrint("Erro ao atualizar status: $e");
    }
  }

  Future<void> _saveToHistory({
    required String id, required String title, required String body,
    required String type, required String horarioFiltro
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('notifications_history').doc(id)
        .set({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'horarioFiltro': horarioFiltro,
      'dataSimples': hojeStr,
      'type': type,
      'status': 'Pendente',
      'isRead': false,
    }, SetOptions(merge: true));
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalUpdateNotification(
          title: message.notification!.title ?? "Nova Atualização",
          body: message.notification!.body ?? "Confira as novidades!",
        );
      }
    });
  }

  Future<void> _launchStore() async {
    final String packageName = "com.luan1990dev.reedu";
    final Uri url = Platform.isAndroid
        ? Uri.parse("market://details?id=$packageName")
        : Uri.parse("https://apps.apple.com/app/idYOUR_ID");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri webUrl = Uri.parse("https://play.google.com/store/apps/details?id=$packageName");
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showLocalUpdateNotification({required String title, required String body}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reedu_updates', 'Atualizações',
      importance: Importance.max, priority: Priority.high, icon: 'launcher_icon',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('open_store', 'ATUALIZAR AGORA', showsUserInterface: true),
      ],
    );

    await notificationsPlugin.show(
      id: 999,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: 'open_store',
    );
  }

  Future<void> requestAllPermissions(BuildContext context) async {
    await Permission.notification.request();
    final androidPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestExactAlarmsPermission();
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> scheduleCustomNotifications(List<Map<String, dynamic>> schedules) async {
    for (int i = 1; i < 100; i++) await notificationsPlugin.cancel(id: i);
    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (var meal in schedules) {
      String h = "${meal['hour'].toString().padLeft(2, '0')}:${meal['minute'].toString().padLeft(2, '0')}";
      String historyId = "meal_${meal['id']}_$hojeStr";
      await _saveToHistory(id: historyId, title: 'Refeição Reedu 🍽️', body: 'Está na hora do seu ${meal['name']}', type: 'Refeição', horarioFiltro: h);
      await notificationsPlugin.zonedSchedule(
        id: meal['id'] as int, title: 'Refeição Reedu 🍽️', body: 'Está na hora do seu ${meal['name']}',
        payload: "meal|0|$historyId",
        scheduledDate: _nextInstanceOfTime(meal['hour'] as int, meal['minute'] as int),
        notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('reedu_precision', 'Alarmes', importance: Importance.max)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleDailySummary({
    required double waterTotal,  required Map mealChecks,
    required Map<int, bool> monthlyHistory,
  }) async {
    String waterStatus = waterTotal <= 1.0 ? "Crítico ⚠️" : waterTotal <= 3.0 ? "Aceitável 🔵" : "Excelente ✅";
    String check(String key) => (mealChecks[key] == true || (mealChecks[key] is num && mealChecks[key] > 0)) ? "✅" : "❌";

    String mealSummary =
        "☕ Café: ${check('Café da Manhã')}\n"
        "🥪 Lanche M: ${check('Lanche da Manhã')}\n"
        "🍲 Almoço: ${check('Almoço')}\n"
        "🍌 Lanche T: ${check('Lanche da Tarde 2')}\n"
        "🍽️ Jantar: ${check('Jantar')}";

    String fullMessage = "Água: ${waterTotal.toStringAsFixed(1)}L ($waterStatus)\n\n$mealSummary";

    await notificationsPlugin.zonedSchedule(
      id: 777,
      title: "Resumo do seu dia anterior 📊",
      body: "Água: ${waterTotal.toStringAsFixed(1)}L (Puxe para ver)",
      scheduledDate: _nextInstanceOfTime(08,15).add(const Duration(days: 1)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'reedu_summary_channel',
          'Resumo Diário',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(fullMessage), // Texto expandido
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWaterReminders(double dailyTotal) async {
    for (int i = 200; i < 300; i++) await notificationsPlugin.cancel(id: i);
    double targetPerCycle = dailyTotal / 4;
      double dose = targetPerCycle / 4;
    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final List<Map<String, dynamic>> schedule = [
      {'id': 201, 'h': 7, 'm': 0, 'type': 'start', 'period': '07:00 - 12:00', 'msg': 'Início do ciclo da manhã! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 202, 'h': 8, 'm': 0, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Hora de beber água!'},
      {'id': 203, 'h': 9, 'm': 0, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Não esqueça de se hidratar!'},
      {'id': 204, 'h': 10, 'm': 0, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Mais um pouco de água!'},
      {'id': 205, 'h': 11, 'm': 0, 'type': 'ask', 'period': '07:00 - 12:00', 'msg': 'Última hidratação antes do almoço!'},
      {'id': 206, 'h': 12, 'm': 0, 'type': 'end', 'period': '07:00 - 12:00', 'msg': 'Fim do ciclo da manhã.'},
      {'id': 207, 'h': 13, 'm': 0, 'type': 'start', 'period': '13:00 - 15:00', 'msg': 'Início do primeiro ciclo da tarde! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 208, 'h': 14, 'm': 0, 'type': 'ask', 'period': '13:00 - 15:00', 'msg': 'Não esqueça de se hidratar!'},
      {'id': 209, 'h': 15, 'm': 0, 'type': 'end', 'period': '13:00 - 15:00', 'msg': 'Fim do ciclo da tarde.'},
      {'id': 210, 'h': 16, 'm': 30, 'type': 'ask', 'period': '15:00 - 18:30', 'msg': 'Início do segundo ciclo da tarde! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 211, 'h': 17, 'm': 30, 'type': 'ask', 'period': '15:00 - 18:30', 'msg': 'Mais um copo de água!'},
      {'id': 212, 'h': 18, 'm': 30, 'type': 'end', 'period': '15:00 - 18:30', 'msg': 'Fim do ciclo da tarde.'},
      {'id': 213, 'h': 19, 'm': 0, 'type': 'ask', 'period': '18:30 - 22:00', 'msg': 'Início do ciclo da noite! A meta é: ${targetPerCycle.toStringAsFixed(1)}L'},
      {'id': 214, 'h': 22, 'm': 0, 'type': 'ask', 'period': '18:30 - 22:00', 'msg': 'Não esqueça da água!'},
      {'id': 215, 'h': 21, 'm': 0, 'type': 'ask', 'period': '18:30 - 22:00', 'msg': 'Essa é a hidratação final!'},
      {'id': 216, 'h': 22, 'm': 0, 'type': 'end', 'period': '18:30 - 22:00', 'msg': 'Fim do ciclo da noite. Bom descanso!'},
    ];

    for (var alarm in schedule) {
      String h = "${alarm['h'].toString().padLeft(2, '0')}:${alarm['m'].toString().padLeft(2, '0')}";
      String historyId = "agua_${alarm['id']}_$hojeStr";
      await _saveToHistory(id: historyId, title: 'Reedu - Água 💧', body: alarm['msg'], type: 'Água', horarioFiltro: h);
      await notificationsPlugin.zonedSchedule(
        id: alarm['id'] as int, title: 'Reedu - Água 💧', body: alarm['msg'],
        payload: "${alarm['period']}|$dose",
        scheduledDate: _nextInstanceOfTime(alarm['h'] as int, alarm['m'] as int),
        notificationDetails: NotificationDetails(android: AndroidNotificationDetails('reedu_water_cycle', 'Hidratação', importance: Importance.max, priority: Priority.high, actions: [const AndroidNotificationAction('water_ok', 'OK ✅', showsUserInterface: true), const AndroidNotificationAction('water_fail', 'NOK ❌', showsUserInterface: true,)])),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      _saveToHistory(id: "agua_${alarm['id']}_$hojeStr", title: 'Reedu - Água 💧', body: alarm['msg'], type: 'Água', horarioFiltro: h);
    }
  }

  NotificationDetails _buildWaterDetails(String msg) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'reedu_water_cycle', 'Hidratação',
        importance: Importance.max,
        priority: Priority.high,
        actions: [
          const AndroidNotificationAction('water_ok', 'OK ✅', showsUserInterface: true),
          const AndroidNotificationAction('water_fail', 'NOK ❌', showsUserInterface: true),
        ],
        color: const Color(0xFF1967D2),
        styleInformation: BigTextStyleInformation(msg),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    return date.isBefore(now) ? date.add(const Duration(days: 1)) : date;
  }

  Future<void> cancelAllNotifications() async => await notificationsPlugin.cancelAll();
}