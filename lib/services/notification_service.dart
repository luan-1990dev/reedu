import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz.initializeTimeZones();

    try {
      // O FlutterTimezone pode retornar uma String ou um objeto TimezoneInfo
      // dependendo da versão (v5.x). Usamos dynamic para evitar erro de tipo.
      final dynamic location = await FlutterTimezone.getLocalTimezone();
      String locationName = location.toString();

      // LIMPEZA: Se o retorno for "TimezoneInfo(America/Sao_Paulo, ...)"
      // extraímos apenas o ID "America/Sao_Paulo"
      if (locationName.contains('(')) {
        locationName = locationName.split('(').last.split(',').first.replaceAll(')', '').trim();
      }

      tz.setLocalLocation(tz.getLocation(locationName));
      debugPrint("Fuso horário configurado: $locationName");
    } catch (e) {
      debugPrint("Erro ao configurar fuso horário: $e. Usando padrão America/Sao_Paulo.");
      // Fallback para o fuso de Brasília caso a detecção falhe
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Se clicar em "Desativar" na notificação, ela é cancelada
        if (response.actionId == 'dismiss_alarm') {
          notificationsPlugin.cancel(response.id!);
        }
      },
    );
  }

  // Agenda lembretes de Água (4 períodos do dia)
  Future<void> scheduleWaterReminders(double dailyTotal) async {
    // Limpa agendamentos de água anteriores (IDs 200 a 210)
    for (int i = 200; i < 210; i++) await notificationsPlugin.cancel(i);

    double portion = dailyTotal / 4;
    final List<Map<String, dynamic>> slots = [
      {'id': 200, 'h': 7, 'm': 0, 'p': '07:00 - 12:00'},
      {'id': 201, 'h': 13, 'm': 0, 'p': '13:00 - 15:00'},
      {'id': 202, 'h': 15, 'm': 0, 'p': '15:00 - 18:30'},
      {'id': 203, 'h': 18, 'm': 30, 'p': '18:30 - 22:00'},
    ];

    for (var slot in slots) {
      final String timeStr = '${slot['h']}:${slot['m'].toString().padLeft(2, '0')}';

      await notificationsPlugin.zonedSchedule(
        slot['id'],
        'Próximo alarme: $timeStr',
        'Beba ${portion.toStringAsFixed(1)}L de água (${slot['p']})',
        _nextInstanceOfTime(slot['h'] as int, slot['m'] as int),
        _notificationDetails('Lembrete de Água'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Agenda alarmes de refeições customizadas
  Future<void> scheduleCustomNotifications(List<Map<String, dynamic>> schedules) async {
    // Limpa agendamentos de refeições (IDs 1 a 100)
    for (int i = 1; i < 100; i++) await notificationsPlugin.cancel(i);

    for (var meal in schedules) {
      final int hour = meal['hour'];
      final int minute = meal['minute'];
      final String timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      await notificationsPlugin.zonedSchedule(
        meal['id'],
        'Próximo alarme: $timeStr',
        'Está na hora do seu ${meal['name']}',
        _nextInstanceOfTime(hour, minute),
        _notificationDetails('Alarme de Refeição'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Configuração visual da notificação (Xiaomi/Android 14 friendly)
  NotificationDetails _notificationDetails(String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'reedu_precision_alerts',
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true, // Acorda a tela em alguns aparelhos
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'dismiss_alarm',
            'Desativar',
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> requestAllPermissions(BuildContext context) async {
    // Solicita permissão de notificações
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    // Solicita permissão de alarme exato (Obrigatório Android 13+)
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    // Solicita permissão para ignorar otimização de bateria (Crucial para Xiaomi/MIUI)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}