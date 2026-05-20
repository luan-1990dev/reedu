import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    final statsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .snapshots();

    final alertsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Calendário de Hábitos",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: statsStream,
        builder: (context, statsSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: alertsStream,
            builder: (context, alertsSnapshot) {
              Map<int, String> dayStatus = {};

              if (statsSnapshot.hasData) {
                for (var doc in statsSnapshot.data!.docs) {
                  DateTime date = DateTime.parse(doc.id);
                  if (date.month == now.month && date.year == now.year) {
                    var data = doc.data() as Map<String, dynamic>;
                    var mealChecks = data['meal_checks'] as Map? ?? {};
                    if (mealChecks.isNotEmpty) {
                      bool followedPlan = !mealChecks.values.any((v) => v == null || v == false);
                      dayStatus[date.day] = followedPlan ? "green" : "red";
                    }
                  }
                }
              }

              if (alertsSnapshot.hasData) {
                for (var doc in alertsSnapshot.data!.docs) {
                  DateTime date = DateTime.parse(doc.id);
                  if (date.month == now.month && date.year == now.year) {
                    var data = doc.data() as Map<String, dynamic>;
                    String status = data['status'] ?? "pending";
                    if (dayStatus[date.day] == null || dayStatus[date.day] == "pending") {
                      dayStatus[date.day] = status;
                    }
                  }
                }
              }

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildHeader(now),
                    const SizedBox(height: 30),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 15,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: lastDayOfMonth.day,
                        itemBuilder: (context, index) {
                          int day = index + 1;
                          String status = dayStatus[day] ?? "pending";
                          return _buildDayTile(day, now, status);
                        },
                      ),
                    ),
                    _buildLegend(),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 🔹 Métodos auxiliares dentro da classe

  Widget _buildHeader(DateTime now) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1967D2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            DateFormat('MMMM yyyy', 'pt_BR').format(now).toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(int day, DateTime now, String status) {
    bool isToday = day == now.day;

    Color bgColor = Colors.white;
    Color borderColor = Colors.black12;
    Color textColor = Colors.black87;

    if (status == "green") {
      bgColor = Colors.green.shade500;
      borderColor = Colors.green;
      textColor = Colors.white;
    } else if (status == "red") {
      bgColor = Colors.red.shade500;
      borderColor = Colors.red;
      textColor = Colors.white;
    } else if (isToday) {
      borderColor = const Color(0xFF1967D2);
      textColor = const Color(0xFF1967D2);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isToday ? 2 : 1),
        boxShadow: [
          if (status != "pending")
            BoxShadow(
                color: bgColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(
            fontWeight: isToday || status != "pending" ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _legendItem(Colors.transparent, Colors.grey, "Pendente"),
              const SizedBox(width: 15),
              _legendItem(Colors.transparent, Colors.green, "No Plano"),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendItem(Colors.transparent, Colors.red, "Fora do Plano"),
              const SizedBox(width: 15),
              _legendItem(Colors.transparent, const Color(0xFF1967D2), "Hoje"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, Color border, String label) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
