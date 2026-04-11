import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Lógica para quando clicar em "Desativar" ou na notificação
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

  Future<void> scheduleWaterReminders() async {
    for(int i = 100; i < 120; i++) {
      await notificationsPlugin.cancel(i);
    }

    final List<Map<String, dynamic>> waterSchedule = [
      {'h': 7, 'm': 30, 'msg': 'Bom dia! Comece seu 1º litro do dia. 💧'},
      {'h': 9, 'm': 45, 'msg': 'Meio da manhã! Continue hidratando para bater 1L até meio-dia.'},
      {'h': 11, 'm': 30, 'msg': 'Quase lá! Falta pouco para completar seu 1º litro!'},
      {'h': 13, 'm': 15, 'msg': 'Hora de começar o 2º litro! Vamos lá? 🌊'},
      {'h': 14, 'm': 40, 'msg': 'Reta final do 2º litro! Não esqueça de beber agora.'},
      {'h': 15, 'm': 45, 'msg': '3º litro iniciado! Mantenha o foco na hidratação. 🧊'},
      {'h': 17, 'm': 15, 'msg': 'Hora da água! O 3º litro está quase batido.'},
      {'h': 18, 'm': 15, 'msg': 'Finalizando o período da tarde. Garanta seu 3º litro!'},
      {'h': 19, 'm': 30, 'msg': 'Iniciando o último litro do dia! 🌑'},
      {'h': 21, 'm': 00, 'msg': 'Quase batendo a meta diária de 4L! Beba um copo agora.'},
      {'h': 21, 'm': 45, 'msg': 'Último gole do dia! Meta de 4L concluída? Parabéns! 🎉'},
    ];

    for (int i = 0; i < waterSchedule.length; i++) {
      final item = waterSchedule[i];
      await notificationsPlugin.zonedSchedule(
        100 + i,
        'Meta de Água Reedu 💧',
        item['msg'],
        _nextInstanceOfTime(item['h'], item['m']),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_precision_channel', 'Metas de Água',
            channelDescription: 'Lembretes precisos por volume e horário',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFF2196F3),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

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

      DateTime mealTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
      
      // Agenda exatamente para o horário (ou 10 min antes se preferir, mas para parecer alarme usamos o horário real)
      await notificationsPlugin.zonedSchedule(
        id,
        'Próximo alarme: $timeStr',
        name,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reedu_alarm_channel', 'Alarmes de Refeição',
            channelDescription: 'Notificações estilo sistema para refeições',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
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
