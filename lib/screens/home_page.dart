import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'assessment_page.dart';
import 'notification_history_page.dart';
import 'recipes_page.dart';
import 'supplementation_page.dart';
import 'menu_page.dart';
import 'diet_page.dart';
import 'weight_monthly_page.dart';
import 'calendar_page.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:wakelock_plus/wakelock_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notifications = NotificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    WakelockPlus.enable();
    _initNotifications();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
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
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Image.asset(
                    'assets/icon/app_icon.home.png',
                    height: 250,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('REEDU'),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_on, color: Colors.orange),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationHistoryPage())),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () async => await FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _db.userProfileStream,
                builder: (context, profileSnap) {
                  if (profileSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: CircularProgressIndicator(color: primaryOceanGreen),
                      ),
                    );
                  }
                  final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
                  final String displayName = _getDisplayName(profileData);
                  final nextMeal = _getNextMealInfo(profileData?['meal_schedules'], profileData?['menu']);
                  final double waterTarget = (profileData?['waterTarget'] ?? 4.0).toDouble();
                  final List<String> waterIntervals = List<String>.from(profileData?['waterIntervals'] ?? ['07:00-12:00', '13:00-15:00', '15:00-18:30', '18:30-22:00']);
                  final int totalAgendado = (profileData?['meal_schedules'] as List?)?.length ?? 6;

                  return StreamBuilder<QuerySnapshot>(                    // Buscamos todos os registros do mês para montar o histórico do calendário
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .collection('daily_stats')
                        .snapshots(),
                    builder: (context, monthlySnap) {
                      Map<int, bool> realMonthlyHistory = {};

                      if (monthlySnap.hasData) {
                        for (var doc in monthlySnap.data!.docs) {
                          try {
                            DateTime date = DateTime.parse(doc.id);
                            if (date.month == DateTime.now().month) {
                              var data = doc.data() as Map<String, dynamic>;
                              var checks = data['meal_checks'] as Map? ?? {};
                              realMonthlyHistory[date.day] = checks.length >= totalAgendado && totalAgendado > 0;
                            }
                          } catch (e) {
                            debugPrint("Erro ao processar data do histórico: $e");
                          }
                        }
                      }

                      return StreamBuilder<DocumentSnapshot>(
                        stream: _db.todayStats,
                        builder: (context, statsSnap) {
                          final statsData = statsSnap.data?.data() as Map<String, dynamic>?;
                          final mealChecks = Map<String, dynamic>.from(statsData?['meal_checks'] ?? {});
                          final waterChecks = Map<String, dynamic>.from(statsData?['water_checks'] ?? {});

                          double totalBeberado = 0;
                          waterChecks.forEach((key, value) {
                            if (value == true || (value is num && value > 0)) {
                              totalBeberado += (waterTarget / 4);
                            }
                          });

                          _notifications.scheduleDailySummary(
                            waterTotal: totalBeberado,
                            mealChecks: mealChecks,
                            monthlyHistory: realMonthlyHistory,
                          );

                          return StreamBuilder<QuerySnapshot>(
                            stream: _db.weightHistory,
                            builder: (context, weightSnap) {
                              List<FlSpot> weightSpots = [];
                              List<String> weightDates = [];

                              if (weightSnap.hasData && weightSnap.data!.docs.isNotEmpty) {
                                Map<String, double> uniqueDays = {};
                                var docs = weightSnap.data!.docs;

                                for (var doc in docs) {
                                  try {
                                    var data = doc.data() as Map<String, dynamic>;
                                    var ts = data['timestamp'] as Timestamp?;

                                    if (data.containsKey('Peso') && ts != null) {
                                      String dateLabel = DateFormat('dd/MM').format(ts.toDate());
                                      double w = double.tryParse(data['Peso'].toString().replaceAll(',', '.')) ?? 0;

                                      if (w > 0) {
                                        uniqueDays[dateLabel] = w;
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint("Erro ao processar registro de peso: $e");
                                  }
                                }
                                List<String> allLabels = uniqueDays.keys.toList();
                                int start = allLabels.length > 7 ? allLabels.length - 7 : 0;
                                int idx = 0;

                                for (int i = start; i < allLabels.length; i++) {
                                  String date = allLabels[i];
                                  weightDates.add(date);
                                  weightSpots.add(FlSpot(idx.toDouble(), uniqueDays[date]!));
                                  idx++;
                                }
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildGreeting(displayName, profileData?['photoUrl'], primaryOceanGreen),
                                  const SizedBox(height: 10),
                                  _buildDietHeader(context, primaryOceanGreen, profileData),
                                  const SizedBox(height: 15),
                                  _buildHeaderMenu(context),
                                  const SizedBox(height: 15),
                                  _buildSuggestionCard(nextMeal, mealChecks, primaryOceanGreen),
                                  const SizedBox(height: 25),
                                  const Text('Checklist do Dia',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  _buildChecklist(mealChecks, profileData?['meal_schedules']),
                                  const SizedBox(height: 25),
                                  _buildWeightSection(primaryOceanGreen, weightSpots, weightDates),
                                  const SizedBox(height: 25),
                                  _buildWaterPanel(waterTarget, waterIntervals, waterChecks, primaryOceanGreen),
                                  const SizedBox(height: 40),
                                ],
                              );
                            }, // Fim do weightSnap builder
                          );
                        }, // Fim do statsSnap builder
                      );
                    }, // Fim do monthlySnap builder
                  );
                }, // Fim do profileSnap builder
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietHeader(BuildContext ctx, Color color, Map<String, dynamic>? profileData) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const DietPage())),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.description_outlined, color: color, size: 24)),
              const SizedBox(width: 15),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('PLANO ALIMENTAR', style: TextStyle(fontWeight: FontWeight.bold)), Text('Clique para ver detalhes', style: TextStyle(fontSize: 11, color: Colors.grey))]),
            ]),
          ),
        ),
        IconButton(icon: Icon(Icons.edit, color: color, size: 20), onPressed: () => _showEditMealScheduleDialog(profileData)),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ]),
    );
  }

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      if (url.startsWith('http')) {
        return NetworkImage(url);
      }

      if (url.startsWith('/') && !url.contains(' ')) {
        final file = File(url);
        if (file.existsSync()) {
          return FileImage(file);
        }
      }

      String cleanBase64 = url.split(',').last.trim();
      return MemoryImage(base64Decode(cleanBase64));

    } catch (e) {
      debugPrint("Erro ao carregar avatar: $e");
      return null;
    }
  }

  Widget _buildGreeting(String name, String? url, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isLoading ? null : () => _pickAndSavePhoto(),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.1),
                  // USANDO A FUNÇÃO SEGURA AQUI:
                  backgroundImage: _getAvatarImage(url),
                  child: (url == null || url.isEmpty)
                      ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color
                    ),
                  )
                      : null,
                ),
                if (!_isLoading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.add_circle, color: color, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $name!',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1C1E)),
                ),
                Text(
                  'Vamos focar no plano hoje? 🎯',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSavePhoto() async {
    final ImagePicker picker = ImagePicker();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    // 1. Seleciona a imagem da galeria
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 400,
    );

    if (image != null) {
      try {
        setState(() => _isLoading = true);

        File file = File(image.path);
        Uint8List imageBytes = await file.readAsBytes();
        String base64Image = base64Encode(imageBytes);

        // 3. Salva a String no Firestore (campo photoUrl)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'photoUrl': base64Image}, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Foto atualizada! ✅"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        debugPrint("Erro ao converter foto: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildHeaderMenu(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _buildHeaderIcon(icon: Icons.restaurant_menu, color: Colors.green, label: 'Cardápio', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPage()))),
      _buildHeaderIcon(icon: Icons.medication, color: Colors.purple, label: 'Suplementos', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplementationPage()))),
      _buildHeaderIcon(icon: Icons.kitchen, color: Colors.orange, label: 'Receitas', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesPage()))),
      _buildHeaderIcon(icon: Icons.bar_chart, color: Colors.blue, label: 'Avaliação', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssessmentPage()))),
      _buildHeaderIcon(icon: Icons.calendar_month, color: Colors.indigo, label: 'Calendário', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage()))),
    ]);
  }

  Widget _buildWeightSection(Color color, List<FlSpot> spots, List<String> dates) {
    const Color themeBlue = Color(0xFF1967D2);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Expanded(child: Text('Peso Semanal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightMonthlyPage())),
          icon: const Icon(Icons.insights_outlined, size: 14),
          label: const Text("VER MÊS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.withOpacity(0.1), foregroundColor: Colors.blueGrey.shade700, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        ),
        const SizedBox(width: 4),
        ElevatedButton.icon(
          onPressed: () => _showAddWeightDialog(),
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
          lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipColor: (spot) => themeBlue, getTooltipItems: (touched) => touched.map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} kg', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList())),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 30, getTitlesWidget: (v, m) { int i = v.toInt(); return (i >= 0 && i < dates.length) ? SideTitleWidget(meta: m, space: 10, child: Text(dates[i], style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))) : const SizedBox(); })),
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

  Widget _buildChecklist(Map<String, dynamic> mealChecks, List<dynamic>? mealSchedules) {
    if (mealSchedules == null || mealSchedules.isEmpty) return const SizedBox();
    List<dynamic> sorted = List.from(mealSchedules);
    sorted.sort((a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int)).compareTo((b['hour'] as int) * 60 + (b['minute'] as int)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: sorted.map((meal) {
          String name = meal['name'];
          bool isDone = mealChecks[name] != null;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(name.contains(' ') ? name.split(' ')[0] : name, style: TextStyle(color: isDone ? Colors.white : Colors.black87, fontSize: 12)),
              selected: isDone,
              onSelected: (v) => _db.toggleMealCompletion(name, v ? "OK" : null),
              selectedColor: const Color(0xFF00695C),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionCard(Map meal, Map checks, Color color) {
    final List<String> options = List<String>.from(meal['options'] ?? []);
    final dynamic currentMealStatus = checks[meal['key']];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('SUGESTÃO AGORA', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2)),
            Text(meal['time'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(meal['title'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          ...options.map((opt) => _buildOptionTile(text: opt, isSelected: currentMealStatus == opt, themeColor: color, onTap: () => _db.toggleMealCompletion(meal['key'], opt))).toList(),
        ],
      ),
    );
  }

  Widget _buildOptionTile({required String text, required bool isSelected, required Color themeColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? Colors.white : Colors.white.withOpacity(0.2), width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? themeColor : Colors.white70, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: isSelected ? const Color(0xFF1A1C1E) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14))),
        ]),
      ),
    );
  }

  Widget _buildWaterPanel(double target, List<String> intervals, Map checks, Color color) {
    final String portion = "${(target / 4).toStringAsFixed(1)}L";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF03A9F4), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [const Icon(Icons.water_drop, color: Colors.white, size: 20), const SizedBox(width: 10), Text('METAS DE ÁGUA (${target.toStringAsFixed(1)}L)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]),
          IconButton(icon: const Icon(Icons.edit, color: Colors.white, size: 20), onPressed: () => _showEditDailyWaterGoalDialog(target, intervals)),
        ]),
        ...intervals.map((time) {
          final bool isChecked = (checks[time] == true || (checks[time] is num && checks[time] > 0));
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(time, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              GestureDetector(onTap: () => _db.toggleWaterSlot(time, !isChecked), child: Icon(isChecked ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.white, size: 26)),
              Text(portion, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required Color color, required String label, required VoidCallback onPressed}) {
    return InkWell(onTap: onPressed, child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))]));
  }

  void _showEditMealScheduleDialog(Map<String, dynamic>? profileData) {
    final List<dynamic> currentSchedules = profileData?['meal_schedules'] ?? [];
    List<Map<String, dynamic>> tempSchedules = List.from(currentSchedules.map((e) => Map<String, dynamic>.from(e)));
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          tempSchedules.sort((a, b) => (a['hour'] * 60 + a['minute']).compareTo(b['hour'] * 60 + b['minute']));
          return AlertDialog(
            title: const Text('Horários das Refeições'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tempSchedules.length,
                itemBuilder: (context, index) {
                  final meal = tempSchedules[index];
                  final time = TimeOfDay(hour: meal['hour'], minute: meal['minute']);
                  return ListTile(
                    title: Text(meal['name']),
                    trailing: TextButton(
                      child: Text(time.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: time);
                        if (picked != null) setDialogState(() { tempSchedules[index]['hour'] = picked.hour; tempSchedules[index]['minute'] = picked.minute; });
                      },
                    ),
                  );
                },
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            actions: [
              // Botão CANCELAR (Estilo Oval)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  side: BorderSide(color: Colors.grey.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              // Botão SALVAR (Estilo Oval)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF00695C),
                  elevation: 0,
                  shape: const StadiumBorder(),
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                ),
                onPressed: () async {
                  try {
                    // 1. Salva a nova lista no Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .set({'meal_schedules': tempSchedules}, SetOptions(merge: true));

                    // 2. Atualiza os agendamentos de notificações
                    await _notifications.scheduleCustomNotifications(tempSchedules);

                    if (mounted) {
                      Navigator.pop(context); // Fecha o diálogo

                      // 3. Exibe a confirmação visual
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Horários das refeições atualizados! 🔄", textAlign: TextAlign.center),
                          backgroundColor: const Color(0xFF00695C),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Erro ao salvar horários: $e");
                  }
                },
                child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
  void _showEditDailyWaterGoalDialog(double currentTarget, List<String> currentIntervals) {
    final targetController = TextEditingController(
      text: currentTarget.toStringAsFixed(1).replaceAll('.', ','),
    );

    final List<TextEditingController> startHourControllers = [];
    final List<TextEditingController> startMinuteControllers = [];
    final List<TextEditingController> endHourControllers = [];
    final List<TextEditingController> endMinuteControllers = [];

    for (var interval in currentIntervals) {
      final parts = interval.split(RegExp(r'[:\- ]+')).where((p) => p.isNotEmpty).toList();
      startHourControllers.add(TextEditingController(text: parts.length > 0 ? parts[0] : "00"));
      startMinuteControllers.add(TextEditingController(text: parts.length > 1 ? parts[1] : "00"));
      endHourControllers.add(TextEditingController(text: parts.length > 2 ? parts[2] : "00"));
      endMinuteControllers.add(TextEditingController(text: parts.length > 3 ? parts[3] : "00"));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text('Meta e Horários de Água', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,]?\d*'))],
                style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: "Meta Diária", suffixText: "Litros"),
              ),
              const SizedBox(height: 25),
              ...List.generate(currentIntervals.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMiniField(startHourControllers[index], "HH"),
                      const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildMiniField(startMinuteControllers[index], "MM"),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text("-", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      _buildMiniField(endHourControllers[index], "HH"),
                      const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildMiniField(endMinuteControllers[index], "MM"),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              elevation: 0,
              shape: const StadiumBorder(),
              side: BorderSide(color: Colors.grey.shade200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              foregroundColor: Colors.green.shade700,
              elevation: 0,
              shape: const StadiumBorder(),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 25),
            ),
            onPressed: () async {
              setState(() => _isLoading = true);

              final val = double.tryParse(targetController.text.replaceAll(',', '.')) ?? 4.0;

              final List<String> newIntervals = [];
              for (int i = 0; i < currentIntervals.length; i++) {
                String sh = startHourControllers[i].text.padLeft(2, '0');
                String sm = startMinuteControllers[i].text.padLeft(2, '0');
                String eh = endHourControllers[i].text.padLeft(2, '0');
                String em = endMinuteControllers[i].text.padLeft(2, '0');
                newIntervals.add("$sh:$sm - $eh:$em");
              }

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .set({'waterTarget': val, 'waterIntervals': newIntervals}, SetOptions(merge: true));

                await _notifications.scheduleWaterReminders(val, newIntervals);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Metas de água atualizadas! 💧", textAlign: TextAlign.center),
                      backgroundColor: Colors.lightGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                debugPrint("Erro ao salvar: $e");
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(TextEditingController controller, String hint) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  void _showAddWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Peso Atual'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "kg"), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () async {
            if (controller.text.isNotEmpty) {
              await _db.saveAssessment({'Peso': controller.text.replaceAll(',', '.')});
              if (mounted) Navigator.pop(context);
            }
          }, child: const Text('SALVAR')),
        ],
      ),
    );
  }

  Map<String, dynamic> _getNextMealInfo(List<dynamic>? customSchedules, Map<String, dynamic>? customMenu) {
    final now = DateTime.now();
    final currentTimeInMinutes = now.hour * 60 + now.minute;
    if (customSchedules != null && customSchedules.isNotEmpty) {
      List<dynamic> sorted = List.from(customSchedules);
      sorted.sort((a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int)).compareTo((b['hour'] as int) * 60 + (b['minute'] as int)));
      for (var meal in sorted) {
        final mealTime = (meal['hour'] as int) * 60 + (meal['minute'] as int);
        if (mealTime > currentTimeInMinutes - 30) {
          String name = meal['name'];
          String raw = customMenu?[name]?.toString() ?? "";
          return {
            'title': name,
            'time': '${meal['hour'].toString().padLeft(2, '0')}:${meal['minute'].toString().padLeft(2, '0')}',
            'options': raw.split(' • ').where((s) => s.isNotEmpty).toList(),
            'key': name
          };
        }
      }
    }
    return {'title': 'Refeições finalizadas. ', 'time': '--:--', 'options': [''], 'key': 'none'};
  }
}