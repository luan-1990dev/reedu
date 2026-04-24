import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz.initializeTimeZones();
    // Certifique-se de que o ícone @mipmap/launcher_icon existe no seu projeto Android
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Lógica para quando clicar em "Desativar" na barra de notificação
        if (response.actionId == 'dismiss_alarm') {
          notificationsPlugin.cancel(response.id!);
        }
      },
    );
  }

  Future<void> requestAllPermissions(BuildContext context) async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// REGRA: Agenda as 4 notificações diárias de água baseadas na meta total
  /// Esta função deve ser chamada na Home sempre que a meta de água mudar.
  Future<void> scheduleWaterReminders(double dailyTotal) async {
    // Cancela lembretes de água antigos (IDs 200 a 205) para evitar duplicatas
    for (int i = 200; i < 205; i++) {
      await notificationsPlugin.cancel(i);
    }

    // Calcula a quantidade por turno (Meta Total / 4 períodos)
    double portion = dailyTotal / 4;

    // Define os horários de disparo e os textos dos períodos
    final List<Map<String, dynamic>> waterSlots = [
      {'id': 200, 'h': 7, 'm': 0, 'period': '07:00 - 12:00'},
      {'id': 201, 'h': 13, 'm': 0, 'period': '13:00 - 15:00'},
      {'id': 202, 'h': 15, 'm': 0, 'period': '15:00 - 18:30'},
      {'id': 203, 'h': 18, 'm': 30, 'period': '18:30 - 22:00'},
    ];

    for (var slot in waterSlots) {
      final String timeStr = '${slot['h'].toString().padLeft(2, '0')}:${slot['m'].toString().padLeft(2, '0')}';

      await notificationsPlugin.zonedSchedule(
        slot['id'],
        'Próximo alarme: $timeStr', // Título similar à imagem enviada
        'Beber ${portion.toStringAsFixed(1)}L de água (${slot['period']})',
        _nextInstanceOfTime(slot['h'], slot['m']),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_reminders_channel', 'Lembretes de Água',
            channelDescription: 'Notificações diárias para bater a meta de água',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm, // Estilo Alarme
            visibility: NotificationVisibility.public,
            color: Color(0xFF2196F3), // Azul sugestivo
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'dismiss_alarm',
                'Desativar',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // REPETIÇÃO DIÁRIA
      );
    }
  }

  /// Agenda notificações customizadas de refeições (mantendo lógica anterior)
  Future<void> scheduleCustomNotifications(List<Map<String, dynamic>> schedules) async {
    for(int i = 1; i < 100; i++) {
      await notificationsPlugin.cancel(i);
    }

    for (var meal in schedules) {
      final int id = meal['id'];
      final String name = meal['name'].toString().toLowerCase();
      final int hour = meal['hour'];
      final int minute = meal['minute'];
      final String timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      await notificationsPlugin.zonedSchedule(
        id,
        'Próximo alarme: $timeStr',
        name,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reedu_meal_channel', 'Alarmes de Refeição',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss_alarm', 'Desativar', cancelNotification: true),
            ],
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