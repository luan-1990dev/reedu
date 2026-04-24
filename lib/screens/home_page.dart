import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/diet_service.dart';
import '../services/notification_service.dart';
import 'assessment_page.dart';
import 'recipes_page.dart';
import 'supplementation_page.dart';
import 'meal_schedule_page.dart';
import 'menu_page.dart';
import 'diet_page.dart';
import 'weight_monthly_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notifications = NotificationService();
  bool _isUploading = false;
  double? _lastScheduledTarget; // Para evitar agendamentos redundantes

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notifications.initNotification();
    if (mounted) {
      _notifications.requestAllPermissions(context);
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null) {
      setState(() => _isUploading = true);
      await _db.updateProfilePicture(image.path);
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showEditDailyWaterGoalDialog(double currentTarget) {
    final controller = TextEditingController(text: currentTarget.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta Diária de Água'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: "Litros", hintText: "Ex: 4.5"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 4.0;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .set({'waterTarget': val}, SetOptions(merge: true));

                // Dispara o agendamento imediatamente após a edição
                await _notifications.scheduleWaterReminders(val);
                _lastScheduledTarget = val;

                if (mounted) Navigator.pop(context);
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
            decoration: const InputDecoration(hintText: "Ex: 95.5", suffixText: "kg"),
            autofocus: true
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _db.saveAssessment({'Peso': controller.text.trim()});
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
      List<dynamic> sortedSchedules = List.from(customSchedules);
      sortedSchedules.sort((a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int))
          .compareTo((b['hour'] as int) * 60 + (b['minute'] as int)));

      for (var meal in sortedSchedules) {
        final mealTimeInMinutes = (meal['hour'] as int) * 60 + (meal['minute'] as int);
        if (mealTimeInMinutes > currentTimeInMinutes - 30) {
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
            expandedHeight: 150.0,
            floating: false,
            pinned: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: () => AuthService().signOut()
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Image.asset(
                    'assets/icon/app_icon.home.png',
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('REEDU', style: TextStyle(color: primaryOceanGreen, fontWeight: FontWeight.bold, fontSize: 32)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _db.userProfileStream,
                builder: (context, profileSnap) {
                  final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
                  final String displayName = _getDisplayName(profileData);
                  String? photoUrl = profileData?['photoUrl'];
                  final nextMeal = _getNextMealInfo(profileData?['meal_schedules'], profileData?['menu']);
                  final double waterTarget = (profileData?['waterTarget'] ?? 4.0).toDouble();

                  // REGRA: Ao carregar os dados, verifica se precisa agendar as notificações
                  if (_lastScheduledTarget != waterTarget) {
                    _lastScheduledTarget = waterTarget;
                    _notifications.scheduleWaterReminders(waterTarget);
                  }

                  final String portionPerSlot = "${(waterTarget / 4).toStringAsFixed(1)}L";
                  final List<String> intervals = ['07:00 - 12:00', '13:00 - 15:00', '15:00 - 18:30', '18:30 - 22:00'];

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _db.todayStats,
                    builder: (context, statsSnap) {
                      final statsData = statsSnap.data?.data() as Map<String, dynamic>?;
                      final mealChecks = Map<String, dynamic>.from(statsData?['meal_checks'] ?? {});
                      final waterChecks = Map<String, dynamic>.from(statsData?['water_checks'] ?? {});

                      return StreamBuilder<QuerySnapshot>(
                        stream: _db.weightHistory,
                        builder: (context, weightSnap) {
                          List<FlSpot> weightSpots = [];
                          List<String> weightDates = [];

                          if (weightSnap.hasData && weightSnap.data!.docs.isNotEmpty) {
                            var docs = weightSnap.data!.docs;
                            // MOSTRAR APENAS DATA DE UMA SEMANA (7 itens)
                            int startIndex = docs.length > 7 ? docs.length - 7 : 0;
                            int chartIndex = 0;

                            for (int i = startIndex; i < docs.length; i++) {
                              var weight = double.tryParse(docs[i]['Peso'].toString().replaceAll(',', '.')) ?? 0;
                              weightSpots.add(FlSpot(chartIndex.toDouble(), weight));

                              var timestamp = docs[i]['timestamp'] as Timestamp?;
                              weightDates.add(timestamp != null ? DateFormat('dd/MM').format(timestamp.toDate()) : '');
                              chartIndex++;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDietHeader(context, primaryOceanGreen),
                              const SizedBox(height: 25),
                              _buildHeaderMenu(context),
                              const SizedBox(height: 25),
                              _buildGreeting(displayName, photoUrl, primaryOceanGreen),
                              const SizedBox(height: 20),
                              _buildSuggestionCard(nextMeal, mealChecks, primaryOceanGreen),
                              const SizedBox(height: 25),
                              const Text('Checklist do Dia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              _buildChecklist(mealChecks),
                              const SizedBox(height: 25),
                              _buildWeightSection(primaryOceanGreen, weightSpots, weightDates),
                              const SizedBox(height: 25),
                              _buildWaterPanel(waterTarget, portionPerSlot, intervals, waterChecks),
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

  Widget _buildWaterPanel(double waterTarget, String portionPerSlot, List<String> intervals, Map waterChecks) {
    const Color waterBlue = Color(0xFF0288D1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF03A9F4), waterBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: waterBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('METAS DE ÁGUA (${waterTarget.toStringAsFixed(1)}L)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              GestureDetector(
                onTap: () => _showEditDailyWaterGoalDialog(waterTarget),
                child: const Icon(Icons.edit, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...intervals.map((time) => _buildWaterRow(time, portionPerSlot, waterChecks[time] ?? false)).toList(),
        ],
      ),
    );
  }

  Widget _buildWaterRow(String time, String amount, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          GestureDetector(
            onTap: () => _db.toggleWaterSlot(time, !isChecked),
            child: Icon(
                isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                color: Colors.white,
                size: 26
            ),
          ),
          Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildWeightSection(Color color, List<FlSpot> spots, List<String> dates) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Tendência Semanal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightMonthlyPage())),
          child: const Text('VER MÊS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ),
        IconButton(onPressed: _showAddWeightDialog, icon: const Icon(Icons.add_chart, color: Colors.black54, size: 22)),
      ]),
      const SizedBox(height: 10),
      Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
        child: spots.isEmpty
            ? const Center(child: Text("Sem dados"))
            : LineChart(LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} kg\n${dates[spot.x.toInt()]}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < dates.length) {
                    return Text(dates[index], style: const TextStyle(fontSize: 9, color: Colors.grey));
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.black,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  Color dotColor = Colors.yellow;
                  if (index > 0) {
                    double prevY = barData.spots[index - 1].y;
                    if (spot.y > prevY) dotColor = Colors.red;
                    if (spot.y < prevY) dotColor = Colors.lightGreen;
                  }
                  return FlDotCirclePainter(radius: 4, color: dotColor, strokeWidth: 1.5, strokeColor: Colors.black26);
                },
              ),
              belowBarData: BarAreaData(show: true, color: Colors.black.withOpacity(0.02)),
            )
          ],
        )),
      ),
    ]);
  }

  Widget _buildDietHeader(BuildContext context, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPage())),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.description_outlined, color: color, size: 24)),
          const SizedBox(width: 15),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PLANO ALIMENTAR', style: TextStyle(fontWeight: FontWeight.bold)), Text('Clique para ver detalhes', style: TextStyle(fontSize: 11, color: Colors.grey))])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
        ]),
      ),
    );
  }

  Widget _buildHeaderMenu(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _buildHeaderIcon(icon: Icons.restaurant_menu, color: Colors.green, label: 'Cardápio', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPage()))),
      _buildHeaderIcon(icon: Icons.medication, color: Colors.purple, label: 'Suplementos', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplementationPage()))),
      _buildHeaderIcon(icon: Icons.kitchen, color: Colors.orange, label: 'Receitas', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesPage()))),
      _buildHeaderIcon(icon: Icons.alarm, color: Colors.teal, label: 'Alarmes', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealSchedulePage()))),
      _buildHeaderIcon(icon: Icons.bar_chart, color: Colors.blue, label: 'Avaliação', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssessmentPage()))),
    ]);
  }

  Widget _buildGreeting(String name, String? url, Color color) {
    return Row(children: [
      CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), backgroundImage: (url != null && url.startsWith('http')) ? NetworkImage(url) : null, child: url == null ? Text(name[0], style: TextStyle(fontWeight: FontWeight.bold, color: color)) : null),
      const SizedBox(width: 12),
      Text('Olá, $name! Foco hoje.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildSuggestionCard(Map<String, dynamic> nextMeal, Map mealChecks, Color color) {
    bool done = mealChecks[nextMeal['key']] != null;
    return GestureDetector(
      onTap: () {
        _db.toggleMealCompletion(nextMeal['key'], nextMeal['options'][0]);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${nextMeal['title']} marcado!"), backgroundColor: color));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [color, const Color(0xFF00897B)]), borderRadius: BorderRadius.circular(25)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SUGESTÃO AGORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(height: 5),
          Text(nextMeal['title'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(nextMeal['options'][0], style: const TextStyle(color: Colors.white, fontSize: 13))),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _buildChecklist(Map checks) {
    final meals = ['cafe', 'lanche_m', 'almoco', 'lanche_t1', 'jantar'];
    final labels = ['Café', 'Lanche M', 'Almoço', 'Lanche T', 'Jantar'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: List.generate(meals.length, (i) {
        bool checked = checks[meals[i]] != null;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(labels[i], style: TextStyle(color: checked ? Colors.white : Colors.black87)),
            selected: checked,
            onSelected: (val) => _db.toggleMealCompletion(meals[i], val),
            selectedColor: const Color(0xFF00695C),
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      })),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required Color color, required String label, required VoidCallback onPressed}) {
    return InkWell(onTap: onPressed, child: Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    ]));
  }
}