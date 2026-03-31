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
import 'assessment_page.dart';
import 'recipes_page.dart';
import 'supplementation_page.dart';
import 'meal_schedule_page.dart';
import 'menu_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _db = DatabaseService();
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image != null) {
      setState(() => _isUploading = true);
      // Nota: Para um app real, aqui você faria o upload para o Firebase Storage.
      // Como estamos focando no layout, vamos simular a atualização do link no Firestore.
      // Em uma implementação completa, o link viria do Storage.
      await _db.updateProfilePicture(image.path); 
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto atualizada! No APK final ela aparecerá aqui.', textAlign: TextAlign.center),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  Map<String, dynamic> _getNextMealInfo(List<dynamic>? customSchedules) {
    final now = DateTime.now();
    final currentTimeInMinutes = now.hour * 60 + now.minute;

    if (customSchedules != null && customSchedules.isNotEmpty) {
      List<dynamic> sortedSchedules = List.from(customSchedules);
      sortedSchedules.sort((a, b) => ((a['hour'] as int) * 60 + (a['minute'] as int))
          .compareTo((b['hour'] as int) * 60 + (b['minute'] as int)));

      for (var meal in sortedSchedules) {
        final mealTimeInMinutes = (meal['hour'] as int) * 60 + (meal['minute'] as int);
        if (mealTimeInMinutes > currentTimeInMinutes) {
          return {
            'title': meal['name'],
            'time': '${meal['hour'].toString().padLeft(2, '0')}:${meal['minute'].toString().padLeft(2, '0')}',
            'options': DietService.mealOptions[meal['name']] ?? ['Ver plano alimentar'],
            'key': DietService.getMealKey(meal['name'])
          };
        }
      }
      final firstMeal = sortedSchedules.first;
      return {
        'title': firstMeal['name'],
        'time': 'Amanhã às ${firstMeal['hour'].toString().padLeft(2, '0')}:${firstMeal['minute'].toString().padLeft(2, '0')}',
        'options': DietService.mealOptions[firstMeal['name']] ?? [],
        'key': DietService.getMealKey(firstMeal['name'])
      };
    }
    
    final hour = now.hour;
    if (hour < 9) return {'title': 'Café da Manhã', 'time': '05:30', 'options': DietService.mealOptions['Café da Manhã'], 'key': 'cafe'};
    if (hour < 12) return {'title': 'Lanche da Manhã', 'time': '09:00', 'options': DietService.mealOptions['Lanche da Manhã'], 'key': 'lanche_m'};
    if (hour < 15) return {'title': 'Almoço', 'time': '12:30', 'options': DietService.mealOptions['Almoço'], 'key': 'almoco'};
    if (hour < 18) return {'title': 'Lanche da Tarde 1', 'time': '16:00', 'options': DietService.mealOptions['Lanche da Tarde 1'], 'key': 'lanche_t1'};
    if (hour < 20) return {'title': 'Lanche da Tarde 2', 'time': '18:00', 'options': DietService.mealOptions['Lanche da Tarde 2'], 'key': 'lanche_t2'};
    return {'title': 'Jantar', 'time': '20:00', 'options': DietService.mealOptions['Jantar'], 'key': 'jantar'};
  }

  void _showAddWeightDialog(BuildContext context, DatabaseService db) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Peso Atual'),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: "Ex: 95.5", suffixText: "kg"), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () async {
            if (controller.text.isNotEmpty) { await db.saveAssessment({'Peso': controller.text.trim()}); if (context.mounted) Navigator.pop(context); }
          }, child: const Text('SALVAR')),
        ],
      ),
    );
  }

  void _showEditWaterDialog(BuildContext context, DatabaseService db, double current) {
    final controller = TextEditingController(text: current.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Total de Água'),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: "Ex: 2.5", suffixText: "L"), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () async {
            final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
            await db.setWaterTotal(val);
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('SALVAR')),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName, DatabaseService db) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Como quer ser chamado?'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Apelido"), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).update({'nickname': controller.text.trim()});
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    const Color primaryBlue = Color(0xFF1967D2);
    const Color backgroundColor = Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: primaryBlue,
            elevation: 0,
            actions: [
              IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 24), onPressed: () async => await authService.signOut(), tooltip: 'Sair'),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Reedu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryBlue, Color(0xFF4285F4)]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _db.userProfileStream,
              builder: (context, profileSnap) {
                final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
                String fullName = profileData?['nickname'] ?? profileData?['name'] ?? user?.displayName ?? 'Usuário';
                String firstName = fullName.split(' ')[0];
                String? photoUrl = profileData?['photoUrl'];
                final List<dynamic>? schedules = profileData?['meal_schedules'];
                final nextMeal = _getNextMealInfo(schedules);
                final waterTarget = (profileData?['waterTarget'] ?? 4.0) as double;

                return StreamBuilder<DocumentSnapshot>(
                  stream: _db.todayStats,
                  builder: (context, statsSnap) {
                    final statsData = statsSnap.data?.data() as Map<String, dynamic>?;
                    final currentWater = (statsData?['water'] ?? 0.0) as double;
                    final mealChecks = Map<String, dynamic>.from(statsData?['meal_checks'] ?? {});

                    return StreamBuilder<QuerySnapshot>(
                      stream: _db.weightHistory,
                      builder: (context, weightSnap) {
                        double currentWeight = 0;
                        List<FlSpot> weightSpots = [];
                        List<String> dates = [];

                        if (weightSnap.hasData && weightSnap.data!.docs.isNotEmpty) {
                          var docs = weightSnap.data!.docs;
                          for (int i = 0; i < docs.length; i++) {
                            var weight = double.tryParse(docs[i]['Peso'].toString()) ?? 0;
                            weightSpots.add(FlSpot(i.toDouble(), weight));
                            currentWeight = weight;
                            if (docs[i]['timestamp'] != null) {
                              DateTime date = (docs[i]['timestamp'] as Timestamp).toDate();
                              dates.add(DateFormat('dd/MM').format(date));
                            } else { dates.add('--'); }
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildHeaderIcon(icon: Icons.restaurant_menu, color: Colors.green, label: 'Cardápio', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPage()))),
                                    _buildHeaderIcon(icon: Icons.medication_liquid_outlined, color: Colors.purple, label: 'Suplementos', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplementationPage()))),
                                    _buildHeaderIcon(icon: Icons.kitchen, color: Colors.orange, label: 'Receitas', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesPage()))),
                                    _buildHeaderIcon(icon: Icons.access_alarm, color: Colors.teal, label: 'Alarmes', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealSchedulePage()))),
                                    _buildHeaderIcon(icon: Icons.insert_chart_outlined, color: Colors.blue, label: 'Avaliação', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssessmentPage()))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(colors: [primaryBlue, Colors.tealAccent]),
                                          ),
                                          child: CircleAvatar(
                                            radius: 32,
                                            backgroundColor: Colors.white,
                                            backgroundImage: (photoUrl != null && photoUrl.startsWith('/')) 
                                                ? FileImage(File(photoUrl)) as ImageProvider
                                                : null,
                                            child: (photoUrl == null || !photoUrl.startsWith('/')) 
                                                ? Text(firstName.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryBlue))
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0, right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(color: primaryBlue, shape: BoxShape.circle),
                                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                                          ),
                                        ),
                                        if (_isUploading)
                                          const Positioned.fill(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: () => _showEditNameDialog(context, firstName, _db),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [Text('Olá, $firstName!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(width: 4), const Icon(Icons.edit, size: 14, color: Colors.grey)]),
                                      const Text('Foco na evolução hoje.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                    ]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [primaryBlue, Color(0xFF4285F4)]),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [const Icon(Icons.auto_awesome, color: Colors.white, size: 20), const SizedBox(width: 8), Text('SUGESTÃO AGORA', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12))]),
                                    const SizedBox(height: 12),
                                    Text(nextMeal['title']!, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                                    Text('Horário Planejado: ${nextMeal['time']}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                                    const SizedBox(height: 16),
                                    ... (nextMeal['options'] as List).map((opt) {
                                      bool isSelected = mealChecks[nextMeal['key']] == opt;
                                      return GestureDetector(
                                        onTap: () => _db.toggleMealCompletion(nextMeal['key'], !isSelected ? opt : false),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(0.3))),
                                          child: Row(children: [Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? primaryBlue : Colors.white, size: 20), const SizedBox(width: 10), Expanded(child: Text(opt, style: TextStyle(color: isSelected ? primaryBlue : Colors.white, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)))]),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),

                              const Text('Checklist do Dia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                                child: Column(children: [
                                  _buildMealCheckItem('Café da Manhã', 'cafe', mealChecks, _db),
                                  _buildMealCheckItem('Lanche da Manhã', 'lanche_m', mealChecks, _db),
                                  _buildMealCheckItem('Almoço', 'almoco', mealChecks, _db),
                                  _buildMealCheckItem('Lanche da Tarde', 'lanche_t', mealChecks, _db),
                                  _buildMealCheckItem('Jantar', 'jantar', mealChecks, _db),
                                ]),
                              ),
                              const SizedBox(height: 30),

                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tendência de Peso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: () => _showAddWeightDialog(context, _db), icon: const Icon(Icons.add_chart), label: const Text("PESAR AGORA"), style: TextButton.styleFrom(foregroundColor: primaryBlue))]),
                              const SizedBox(height: 12),
                              Container(
                                height: 220, width: double.infinity, padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                                child: weightSpots.isEmpty ? const Center(child: Text("Registre seu peso!")) : LineChart(LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(show: true, topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) { int index = value.toInt(); if (index >= 0 && index < dates.length) return Padding(padding: const EdgeInsets.only(top: 10), child: Text(dates[index], style: const TextStyle(fontSize: 10, color: Colors.grey))); return const Text(''); }))),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [LineChartBarData(spots: weightSpots, isCurved: true, color: primaryBlue, barWidth: 5, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: primaryBlue.withOpacity(0.1)))],
                                )),
                              ),
                              const SizedBox(height: 30),

                              Row(children: [
                                Expanded(child: GestureDetector(onTap: () => _db.addWater(), onLongPress: () => _showEditWaterDialog(context, _db, currentWater), child: _buildSummaryCard(Icons.water_drop, 'Água', '${currentWater.toStringAsFixed(1)}L / ${waterTarget}L', Colors.blue, currentWater / waterTarget))),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryCard(Icons.monitor_weight, 'Peso Atual', '${currentWeight > 0 ? currentWeight : "--"} kg', Colors.purple, 0.7)),
                              ]),
                              const SizedBox(height: 20),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCheckItem(String title, String key, Map<String, dynamic> checks, DatabaseService db) {
    bool isChecked = checks[key] != false && checks[key] != null;
    return CheckboxListTile(title: Text(title, style: TextStyle(fontSize: 15, decoration: isChecked ? TextDecoration.lineThrough : null, color: isChecked ? Colors.grey : Colors.black87, fontWeight: isChecked ? FontWeight.normal : FontWeight.w500)), value: isChecked, activeColor: const Color(0xFF00796B), contentPadding: const EdgeInsets.symmetric(horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), onChanged: (val) => db.toggleMealCompletion(key, val ?? false));
  }

  Widget _buildHeaderIcon({required IconData icon, required Color color, required String label, required VoidCallback onPressed}) {
    return InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(15), child: Padding(padding: const EdgeInsets.all(8.0), child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(height: 6), Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey), overflow: TextOverflow.ellipsis)])));
  }

  Widget _buildSummaryCard(IconData icon, String label, String value, Color color, double progress) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 32), const SizedBox(height: 10), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6))]));
  }
}
