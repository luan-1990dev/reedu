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
  bool _isEditing = false;

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
        setState(() { _isEditing = false; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Agenda atualizada com sucesso!', textAlign: TextAlign.center),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.red ;
    const Color bgSoft = Color(0xFF8B0000);

    return Scaffold(
      backgroundColor: bgSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
            actions: [
              if (!_isEditing) 
                IconButton(icon: const Icon(Icons.edit, color: Colors.black87), onPressed: () => setState(() => _isEditing = true))
              else 
                IconButton(
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2)) 
                    : const Icon(Icons.check, color: Colors.black87, size: 28), 
                  onPressed: _isLoading ? null : _saveSchedules
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Agenda de Alarmes', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryColor, Color(0xFF8B0000)]),
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
                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.alarm, color: Color(0xFFB8860B), size: 24),
                      ),
                      title: _isEditing 
                        ? TextField(
                            onChanged: (val) => _currentSchedules[index]['name'] = val,
                            controller: TextEditingController(text: meal['name']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Nome do Alarme'),
                          )
                        : Text(meal['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(_isEditing ? 'Toque no horário para mudar' : 'Aviso programado', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: GestureDetector(
                        onTap: () => _selectTime(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isEditing ? primaryColor.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${meal['hour'].toString().padLeft(2, '0')}:${meal['minute'].toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFB8860B)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _currentSchedules.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
