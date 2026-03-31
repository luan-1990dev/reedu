import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class MealSchedulePage extends StatefulWidget {
  const MealSchedulePage({super.key});

  @override
  State<MealSchedulePage> createState() => _MealSchedulePageState();
}

class _MealSchedulePageState extends State<MealSchedulePage> {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notifications = NotificationService();
  bool _isLoading = false;
  bool _isDataLoaded = false;

  final List<Map<String, dynamic>> _defaultSchedules = [
    {'id': 1, 'name': 'Café da Manhã', 'hour': 5, 'minute': 30},
    {'id': 2, 'name': 'Lanche da Manhã', 'hour': 9, 'minute': 00},
    {'id': 3, 'name': 'Almoço', 'hour': 12, 'minute': 30},
    {'id': 4, 'name': 'Lanche da Tarde 1', 'hour': 16, 'minute': 00},
    {'id': 5, 'name': 'Lanche da Tarde 2', 'hour': 18, 'minute': 00},
    {'id': 6, 'name': 'Jantar', 'hour': 20, 'minute': 00},
  ];

  List<Map<String, dynamic>> _currentSchedules = [];

  @override
  void initState() {
    super.initState();
    // Inicia com os padrões
    _currentSchedules = List.from(_defaultSchedules.map((item) => Map<String, dynamic>.from(item)));
    _loadSchedulesFromDb();
  }

  Future<void> _loadSchedulesFromDb() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('meal_schedules')) {
        final List<dynamic> dbSchedules = doc.data()!['meal_schedules'];
        setState(() {
          _currentSchedules = List<Map<String, dynamic>>.from(
            dbSchedules.map((item) => Map<String, dynamic>.from(item))
          );
          _isDataLoaded = true;
        });
      }
    }
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _currentSchedules[index]['hour'],
        minute: _currentSchedules[index]['minute'],
      ),
    );
    if (picked != null) {
      setState(() {
        _currentSchedules[index]['hour'] = picked.hour;
        _currentSchedules[index]['minute'] = picked.minute;
      });
    }
  }

  Future<void> _saveSchedules() async {
    setState(() => _isLoading = true);
    try {
      await _db.saveMealSchedule(_currentSchedules);
      await _notifications.scheduleCustomNotifications(_currentSchedules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horários salvos e notificações agendadas!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF00796B);
    const Color bgSoft = Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: bgSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Agenda de Refeições', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryColor, Color(0xFF009688)]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final meal = _currentSchedules[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.alarm, color: Colors.teal, size: 24),
                      ),
                      title: Text(meal['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('Toque para editar o horário', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: Text(
                        '${meal['hour'].toString().padLeft(2, '0')}:${meal['minute'].toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      onTap: () => _selectTime(index),
                    ),
                  );
                },
                childCount: _currentSchedules.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSchedules,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 4,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SALVAR E ATIVAR AVISOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
