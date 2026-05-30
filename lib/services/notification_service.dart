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
      settings:initializationSettings,
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
        _showLocalUpdateNotification(title: message.notification!.title ?? "Atualização", body: message.notification!.body ?? "Confira as novidades!");
      }
    });
  }

  Future<void> _launchStore() async {
    final String packageName = "com.luan1990dev.reedu";
    final Uri url = Platform.isAndroid ? Uri.parse("market://details?id=$packageName") : Uri.parse("https://apps.apple.com/app/idYOUR_ID");
    if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
  }

  Future<void> _showLocalUpdateNotification({required String title, required String body}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails('reedu_updates', 'Atualizações', importance: Importance.max, priority: Priority.high, icon: 'launcher_icon', actions: [const AndroidNotificationAction('open_store', 'ATUALIZAR AGORA', showsUserInterface: true)]);
    await notificationsPlugin.show(id: 999, title: title, body: body, notificationDetails: NotificationDetails(android: androidDetails), payload: 'open_store');
  }

  Future<void> requestAllPermissions(BuildContext context) async {
    await Permission.notification.request();
    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
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
    required double waterTotal,
    required Map mealChecks,
    required Map<int, bool> monthlyHistory,
  }) async {
    String waterStatus = waterTotal <= 1.0 ? "Crítico ⚠️" : waterTotal <= 3.0 ? "Aceitável 🔵" : "Excelente ✅";
    String checkMeal(String keyword) {
      bool done = mealChecks.entries.any((e) =>
      e.key.toString().toLowerCase().contains(keyword.toLowerCase()) &&
          (e.value == true || e.value == "OK" || (e.value is String && e.value.isNotEmpty))
      );
      return done ? "✅" : "❌";
    }
    Map<String, String> iconMap = {
      'café': '',
      'almoço': '',
      'jantar': '',
      'lanche manha': '',
      'lanche tarde': '',
      'lanche noite': '',
      'pre treino': '',
      'pós treino': '',
      'suplemento': '',
      'ceia': '',
    };
    String mealSummary = mealChecks.keys.map((mealName) {
      String icon = '🍴';
      iconMap.forEach((key, value) {
        if (mealName.toLowerCase().contains(key)) icon = value;
      });

      bool done = mealChecks[mealName] == true ||
          mealChecks[mealName] == "OK" ||
          (mealChecks[mealName] is String && mealChecks[mealName].isNotEmpty);

      return "$icon $mealName: ${done ? "✅" : "❌"}";
    }).join('\n');

    if (mealSummary.isEmpty) mealSummary = "Nenhuma refeição registrada.";

    String fullMessage = "Água: ${waterTotal.toStringAsFixed(1)}L ($waterStatus)\n\n$mealSummary";
    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _saveToHistory(
      id: "summary_$hojeStr",
      title: "Resumo do dia anterior 📊",
      body: fullMessage,
      type: "Resumo",
      horarioFiltro: "08:15",
    );

    await notificationsPlugin.zonedSchedule(
      id: 777,
      title: "Resumo do seu dia anterior 📊",
      body: "Água: ${waterTotal.toStringAsFixed(1)}L (Puxe para ver)",
      scheduledDate: _nextInstanceOfTime(08, 15),
      notificationDetails: NotificationDetails(android: AndroidNotificationDetails('reedu_summary_channel', 'Resumo Diário', importance: Importance.max, priority: Priority.high, styleInformation: BigTextStyleInformation(fullMessage))),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWaterReminders(double dailyTotal, List<String> intervals) async {
    for (int i = 200; i < 350; i++) await notificationsPlugin.cancel(id: i);

    double targetPerCycle = dailyTotal / 4;
    double dose = targetPerCycle / 4;
    String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int notificationIdCounter = 200;

    for (int i = 0; i < intervals.length; i++) {
      try {
        String period = intervals[i];
        List<String> times = period.split(' - ');
        String startStr = times[0];
        String endStr = times[1];

        int startHour = int.parse(startStr.split(':')[0]);
        int startMinute = int.parse(startStr.split(':')[1]);
        int endHour = int.parse(endStr.split(':')[0]);
        int endMinute = int.parse(endStr.split(':')[1]);

        // --- 1. INÍCIO DO CICLO ---
        String startHistoryId = "agua_${notificationIdCounter}_$hojeStr";
        await _saveToHistory(
            id: startHistoryId,
            title: 'Ciclo ${i + 1} iniciado! 💧',
            body: 'Meta: ${targetPerCycle.toStringAsFixed(1)}L',
            type: 'Água',
            horarioFiltro: startStr
        );

        await notificationsPlugin.zonedSchedule(
          id: notificationIdCounter++,
          title: 'Reedu - Início do Ciclo 💧',
          body: 'Meta do período: ${targetPerCycle.toStringAsFixed(1)}L',
          payload: "$period|$dose|$startHistoryId",
          scheduledDate: _nextInstanceOfTime(startHour, startMinute),
          notificationDetails: _buildWaterDetails('Hora de começar a se hidratar!'),
          androidScheduleMode: AndroidScheduleMode.alarmClock, // Modo Despertador
          matchDateTimeComponents: DateTimeComponents.time,
        );


        // 2. MEIO DO CICLO (HORAS CHEIAS)
        int currentHour = startHour + 1;
        while (currentHour < endHour) {
          String timeStr = "${currentHour.toString().padLeft(2, '0')}:00";
          String midHistoryId = "agua_${notificationIdCounter}_$hojeStr";
          await _saveToHistory(id: midHistoryId, title: 'Lembrete de Água 💧', body: 'Hora de beber mais um pouco!', type: 'Água', horarioFiltro: timeStr);
          await notificationsPlugin.zonedSchedule(
            id: notificationIdCounter++,
            title: 'Reedu - Hidratação 💧',
            body: 'Mais um pouco (+${dose.toStringAsFixed(2)}L)',
            payload: "$period|$dose|$midHistoryId",
            scheduledDate: _nextInstanceOfTime(currentHour, 0),
            notificationDetails: _buildWaterDetails('Não esqueça da sua meta diária!'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          currentHour++;
        }

        // 3. FIM DO CICLO
        String endHistoryId = "agua_${notificationIdCounter}_$hojeStr";
        String endBody = (i == 3) ? 'Meta concluída. Bom descanso! 🌙' : 'Fim do ciclo ${i + 1}.';
        await _saveToHistory(id: endHistoryId, title: 'Fim de Ciclo ✅', body: endBody, type: 'Água', horarioFiltro: endStr);
        await notificationsPlugin.zonedSchedule(
          id: notificationIdCounter++,
          title: 'Reedu - Ciclo Finalizado ✅',
          body: endBody,
          payload: "$period|$dose|$endHistoryId",
          scheduledDate: _nextInstanceOfTime(endHour, endMinute),
          notificationDetails: _buildWaterDetails('Finalizando período de hidratação.'),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint("Erro ao agendar ciclo de água $i: $e");
      }
    }
  }

  NotificationDetails _buildWaterDetails(String msg) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'reedu_water_cycle', 'Hidratação',
        importance: Importance.max, priority: Priority.high, fullScreenIntent: true,
        actions: [
          const AndroidNotificationAction('water_ok', 'OK ✅', showsUserInterface: true),
          const AndroidNotificationAction('water_fail', 'NOK ❌', showsUserInterface: true),
        ],
        color: const Color(0xFF1967D2),
        styleInformation: BigTextStyleInformation(msg),
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