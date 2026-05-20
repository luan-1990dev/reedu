import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/diet_service.dart';
import '../services/notification_service.dart';
import 'assessment_page.dart';
import 'notification_history.dart';
import 'recipes_page.dart';
import 'supplementation_page.dart';
import 'menu_page.dart';
import 'diet_page.dart';
import 'weight_monthly_page.dart';
import 'calendar_page.dart'; // IMPORTADO

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notifications = NotificationService();
  double? _lastScheduledTarget;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notifications.initNotification();
    if (mounted) {
      _notifications.requestAllPermissions(context);
      _notifications.setupPushNotifications();
    }
  }

  String _getDisplayName(Map<String, dynamic>? profileData) {
    if (profileData?['nickname'] != null && profileData!['nickname'].toString().isNotEmpty) {
      return profileData['nickname'];
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      String namePart = user!.email!.split('@')[0];
      String rawName = namePart.split(RegExp(r'[._-]'))[0];
      return rawName[0].toUpperCase() + rawName.substring(1).toLowerCase();
    }
    return "Usuário";
  }

  void _showEditMealScheduleDialog(Map<String, dynamic>? profileData) {
    final List<String> mealNames = ['Café da Manhã', 'Lanche da Manhã', 'Almoço', 'Lanche da Tarde 1', 'Lanche da Tarde 2', 'Jantar'];
    final List<dynamic> currentSchedules = profileData?['meal_schedules'] ?? [];

    Map<String, TimeOfDay> tempSchedules = {};

    for (var name in mealNames) {
      final existing = currentSchedules.firstWhere((m) => m['name'] == name, orElse: () => null);
      if (existing != null) {
        tempSchedules[name] = TimeOfDay(hour: existing['hour'], minute: existing['minute']);
      } else {
        tempSchedules[name] = const TimeOfDay(hour: 08, minute: 00);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Horários das Refeições'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mealNames.length,
              itemBuilder: (context, index) {
                final name = mealNames[index];
                return ListTile(
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  trailing: TextButton(
                    child: Text(tempSchedules[name]!.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: tempSchedules[name]!,
                      );
                      if (time != null) {
                        setDialogState(() => tempSchedules[name] = time);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                final List<Map<String, dynamic>> finalSchedules = tempSchedules.entries.map((e) {
                  return {
                    'id': tempSchedules.keys.toList().indexOf(e.key) + 1,
                    'name': e.key,
                    'hour': e.value.hour,
                    'minute': e.value.minute,
                  };
                }).toList();

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .set({'meal_schedules': finalSchedules}, SetOptions(merge: true));

                await _notifications.scheduleCustomNotifications(finalSchedules);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Horários atualizados! 🍎"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDailyWaterGoalDialog(double currentTarget, List<String> currentIntervals) {
    final targetController = TextEditingController(text: currentTarget.toStringAsFixed(1).replaceAll('.', ','));
    final List<TextEditingController> intervalControllers = currentIntervals
        .map((interval) => TextEditingController(text: interval))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta e Horários de Água'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,]?\d*'))],
                decoration: const InputDecoration(labelText: "Meta Diária (Litros)", suffixText: "L"),
              ),
              const SizedBox(height: 20),
              const Text("Intervalos (Ex: 07:00 - 12:00):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ...List.generate(4, (index) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: intervalControllers[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9:\- ]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: InputDecoration(labelText: "Período ${index + 1}", isDense: true),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(targetController.text.replaceAll(',', '.')) ?? 4.0;
              final newIntervals = intervalControllers.map((c) => c.text).toList();

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .set({'waterTarget': val, 'waterIntervals': newIntervals}, SetOptions(merge: true));

              await _notifications.scheduleWaterReminders(val);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Metas de água atualizadas! 💧"), backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  void _showAddWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Peso Atual'),
        content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,]?\d*'))],
            decoration: const InputDecoration(hintText: "Ex: 95,5", suffixText: "kg"),
            autofocus: true
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  String sanitizedWeight = controller.text.trim().replaceAll(',', '.');
                  await _db.saveAssessment({'Peso': sanitizedWeight});
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('SALVAR')
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getNextMealInfo(List<dynamic>? customSchedules, Map<String, dynamic>? customMenu) {
    final now = DateTime.now();
    final currentTimeInMinutes = now.hour * 60 + now.minute;

    List<String> getOptions(String mealName) {
      if (customMenu != null && customMenu.containsKey(mealName) && customMenu[mealName].toString().isNotEmpty) {
        return [customMenu[mealName].toString()];
      }
      return DietService.mealOptions[mealName] ?? ['Ver plano detalhado'];
    }

    if (customSchedules != null && customSchedules.isNotEmpty) {
      List<dynamic> sorted = List.from(customSchedules);
      sorted.sort((a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int)).compareTo((b['hour'] as int) * 60 + (b['minute'] as int)));
      for (var meal in sorted) {
        final mealTime = (meal['hour'] as int) * 60 + (meal['minute'] as int);
        if (mealTime > currentTimeInMinutes - 30) {
          return {
            'title': meal['name'],
            'time': '${meal['hour'].toString().padLeft(2, '0')}:${meal['minute'].toString().padLeft(2, '0')}',
            'options': getOptions(meal['name']),
            'key': DietService.getMealKey(meal['name'])
          };
        }
      }
    }
    return {'title': 'Café da Manhã', 'time': '05:30', 'options': getOptions('Café da Manhã'), 'key': 'cafe'};
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryOceanGreen = Color(0xFF00695C);
    const Color bgLight = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 20),
                  child: Image.asset('assets/icon/app_icon.home.png', height: 140, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('REEDU')),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_on, color: Colors.orange),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationHistoryPage()),
                  );
                },
                tooltip: "Historico de notificações",
              ),

              IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: () => AuthService().signOut()
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _db.userProfileStream,
                builder: (context, profileSnap) {
                  final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
                  final String displayName = _getDisplayName(profileData);
                  final nextMeal = _getNextMealInfo(profileData?['meal_schedules'], profileData?['menu']);
                  final double waterTarget = (profileData?['waterTarget'] ?? 4.0).toDouble();
                  final List<String> waterIntervals = List<String>.from(profileData?['waterIntervals'] ?? [
                    '07:00 - 12:00', '13:00 - 15:00', '15:00 - 18:30', '18:30 - 22:00'
                  ]);

                  if (_lastScheduledTarget != waterTarget) {
                    _lastScheduledTarget = waterTarget;
                    _notifications.scheduleWaterReminders(waterTarget);
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _db.todayStats,
                    builder: (context, statsSnap) {
                      final statsData = statsSnap.data?.data() as Map<String, dynamic>?;
                      final mealChecks = Map<String, dynamic>.from(statsData?['meal_checks'] ?? {});
                      final waterChecks = Map<String, dynamic>.from(statsData?['water_checks'] ?? {});

                      double totalBeberado = 0;
                      waterChecks.forEach((key, value) {
                        if (value == true) totalBeberado += (waterTarget / 4);
                      });

                      _notifications.scheduleDailySummary(
                        waterTotal: totalBeberado,
                        mealChecks: mealChecks,
                        monthlyHistory: {},
                      );

                      return StreamBuilder<QuerySnapshot>(
                        stream: _db.weightHistory,
                        builder: (context, weightSnap) {
                          List<FlSpot> weightSpots = [];
                          List<String> weightDates = [];
                          if (weightSnap.hasData && weightSnap.data!.docs.isNotEmpty) {
                            var docs = weightSnap.data!.docs;
                            int start = docs.length > 7 ? docs.length - 7 : 0;
                            int idx = 0;
                            for (int i = start; i < docs.length; i++) {
                              var w = double.tryParse(docs[i]['Peso'].toString().replaceAll(',', '.')) ?? 0;
                              weightSpots.add(FlSpot(idx.toDouble(), w));
                              var ts = docs[i]['timestamp'] as Timestamp?;
                              weightDates.add(ts != null ? DateFormat('dd/MM').format(ts.toDate()) : '');
                              idx++;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDietHeader(context, primaryOceanGreen, profileData),
                              const SizedBox(height: 25),
                              _buildHeaderMenu(context),
                              const SizedBox(height: 25),
                              _buildGreeting(displayName, profileData?['photoUrl'], primaryOceanGreen),
                              const SizedBox(height: 20),
                              _buildSuggestionCard(nextMeal, mealChecks, primaryOceanGreen),
                              const SizedBox(height: 25),
                              const Text('Checklist do Dia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              _buildChecklist(mealChecks),
                              const SizedBox(height: 25),
                              _buildWeightSection(primaryOceanGreen, weightSpots, weightDates),
                              const SizedBox(height: 25),
                              _buildWaterPanel(waterTarget, waterIntervals, waterChecks, primaryOceanGreen),
                              const SizedBox(height: 40),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMenu(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _buildHeaderIcon(icon: Icons.restaurant_menu, color: Colors.green, label: 'Cardápio', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPage()))),
      _buildHeaderIcon(icon: Icons.medication, color: Colors.purple, label: 'Suplementos', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplementationPage()))),
      _buildHeaderIcon(icon: Icons.kitchen, color: Colors.orange, label: 'Receitas', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesPage()))),
      _buildHeaderIcon(icon: Icons.bar_chart, color: Colors.blue, label: 'Avaliação', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssessmentPage()))),

      _buildHeaderIcon(
          icon: Icons.calendar_month,
          color: Colors.indigo,
          label: 'Calendário',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage()))
      ),
    ]);
  }

  Widget _buildWeightSection(Color color, List<FlSpot> spots, List<String> dates) {
    const Color themeBlue = Color(0xFF1967D2);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Expanded(child: Text('Tendência Semanal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightMonthlyPage())),
          icon: const Icon(Icons.insights_outlined, size: 14),
          label: const Text("VER MÊS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.withOpacity(0.1), foregroundColor: Colors.blueGrey.shade700, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        ),
        const SizedBox(width: 4),
        ElevatedButton.icon(
          onPressed: () {
            final String today = DateFormat('dd/MM').format(DateTime.now());
            if (dates.contains(today)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peso já registrado hoje!'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
            } else { _showAddWeightDialog(); }
          },
          icon: const Icon(Icons.add_chart, size: 14),
          label: const Text("PESAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: themeBlue.withOpacity(0.1), foregroundColor: themeBlue, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        ),
      ]),
      const SizedBox(height: 15),
      Container(
        height: 220,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)]),
        padding: const EdgeInsets.fromLTRB(5, 25, 20, 10),
        child: spots.isEmpty ? const Center(child: Text("Sem dados")) : LineChart(LineChartData(
          lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipColor: (spot) => themeBlue, getTooltipItems: (touched) => touched.map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} kg\n${dates[s.x.toInt()]}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))).toList())),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 30, getTitlesWidget: (v, m) { if (v % 1 != 0) return const SizedBox(); int i = v.toInt(); return (i >= 0 && i < dates.length) ? SideTitleWidget(meta: m, space: 10, child: Text(dates[i], style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))) : const SizedBox(); })),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [LineChartBarData(
              spots: spots, isCurved: true, curveSmoothness: 0.35, color: themeBlue, barWidth: 4, isStrokeCapRound: true,
              dotData: FlDotData(show: true, getDotPainter: (spot, p, bar, idx) {
                Color c = Colors.yellow;
                if (idx > 0) {
                  if (spot.y > bar.spots[idx-1].y) c = Colors.orange;
                  if (spot.y < bar.spots[idx-1].y) c = Colors.blue;
                }
                return FlDotCirclePainter(radius: 5, color: c, strokeWidth: 2, strokeColor: Colors.white);
              }),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [themeBlue.withOpacity(0.3), themeBlue.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))
          )],
        )),
      ),
    ]);
  }

  Widget _buildWaterPanel(double target, List<String> intervals, Map checks, Color color) {
    final String portion = "${(target / 4).toStringAsFixed(1)}L";
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF03A9F4), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF0288D1).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [const Icon(Icons.water_drop, color: Colors.white, size: 20), const SizedBox(width: 10), Text('METAS DE ÁGUA (${target.toStringAsFixed(1)}L)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]),
          GestureDetector(onTap: () => _showEditDailyWaterGoalDialog(target, intervals), child: const Icon(Icons.edit, color: Colors.white70, size: 20)),
        ]),
        const SizedBox(height: 20),
        ...intervals.map((time) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          GestureDetector(onTap: () => _db.toggleWaterSlot(time, !(checks[time] ?? false)), child: Icon(((checks[time] ?? 0) > 0) ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.white, size: 26)),
          Text(portion, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]))),
      ]),
    );
  }

  Widget _buildDietHeader(BuildContext ctx, Color color, Map<String, dynamic>? profileData) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const DietPage())),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.description_outlined, color: color, size: 24)),
            const SizedBox(width: 15),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('PLANO ALIMENTAR', style: TextStyle(fontWeight: FontWeight.bold)), Text('Clique para ver detalhes', style: TextStyle(fontSize: 11, color: Colors.grey))]),
          ]),
        ),
        const Spacer(),
        IconButton(icon: Icon(Icons.edit, color: color, size: 20), onPressed: () => _showEditMealScheduleDialog(profileData)),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ]),
    );
  }

  Widget _buildGreeting(String name, String? url, Color color) {
    return Row(children: [CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), backgroundImage: (url != null && url.startsWith('http')) ? NetworkImage(url) : null, child: url == null ? Text(name[0], style: TextStyle(fontWeight: FontWeight.bold, color: color)) : null), const SizedBox(width: 12), Text('Olá, $name! Foco hoje.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]);
  }

  Widget _buildSuggestionCard(Map meal, Map checks, Color color) {
    return Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('SUGESTÃO AGORA', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2)), Text(meal['time'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]), const SizedBox(height: 8), Text(meal['title'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 18), ...List<String>.from(meal['options']).map((opt) { bool sel = checks[meal['key']] == opt; return GestureDetector(onTap: () => _db.toggleMealCompletion(meal['key'], opt), child: AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: sel ? Colors.white : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15), border: Border.all(color: sel ? Colors.white : Colors.white.withOpacity(0.3), width: 1.5)), child: Row(children: [Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked, color: sel ? color : Colors.white, size: 22), const SizedBox(width: 12), Expanded(child: Text(opt, style: TextStyle(color: sel ? color : Colors.white, fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.normal)))]))); }).toList()]));
  }

  Widget _buildChecklist(Map checks) {
    final m = ['cafe', 'lanche_m', 'almoco', 'lanche_t1', 'lanche_t2', 'jantar'];
    final l = ['Café', 'Lanche M', 'Almoço', 'Lanche T1', 'Lanche T2', 'Jantar'];
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(m.length, (i) { bool isDone = checks[m[i]] != null; return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(l[i], style: TextStyle(color: isDone ? Colors.white : Colors.black87)), selected: isDone, onSelected: (v) => _db.toggleMealCompletion(m[i], v ? "OK" : null), selectedColor: const Color(0xFF00695C), checkmarkColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))); })));
  }

  Widget _buildHeaderIcon({required IconData icon, required Color color, required String label, required VoidCallback onPressed}) {
    return InkWell(onTap: onPressed, child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))]));
  }
}
