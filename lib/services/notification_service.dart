import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await notificationsPlugin.initialize(initializationSettings);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  // Novo método: Agenda lembretes de água a cada 3 horas entre 08:00 e 22:00
  Future<void> scheduleWaterReminders() async {
    // Cancela lembretes de água anteriores para não duplicar (IDs de água começam em 100)
    for(int i = 100; i < 110; i++) {
      await notificationsPlugin.cancel(i);
    }

    final waterTimes = [8, 11, 14, 17, 20]; // Horários fixos de lembrete

    for (int i = 0; i < waterTimes.length; i++) {
      await notificationsPlugin.zonedSchedule(
        100 + i, // ID único para água
        'Hora da Água! 💧',
        'Lembre-se de sua meta diária de 4 litros. Já bebeu água nas últimas horas?',
        _nextInstanceOfTime(waterTimes[i], 0),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_channel', 'Lembretes de Água',
            channelDescription: 'Avisos periódicos para hidratação',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleCustomNotifications(List<Map<String, dynamic>> schedules) async {
    // Mantém as notificações de refeição (IDs de 1 a 99)
    for(int i = 1; i < 100; i++) {
      await notificationsPlugin.cancel(i);
    }

    for (var meal in schedules) {
      final int id = meal['id'];
      final String name = meal['name'];
      final int hour = meal['hour'];
      final int minute = meal['minute'];

      DateTime mealTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
      DateTime notificationTime = mealTime.subtract(const Duration(minutes: 10));

      await notificationsPlugin.zonedSchedule(
        id,
        'Hora do $name! 🍎',
        'Seu horário planejado é às ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}.',
        _nextInstanceOfTime(notificationTime.hour, notificationTime.minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reedu_meals_channel', 'Lembretes de Refeição',
            channelDescription: 'Avisos antecipados das refeições do plano',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
