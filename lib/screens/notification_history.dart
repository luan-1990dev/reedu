import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationHistoryPage extends StatelessWidget {
  const NotificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    // Filtros de tempo
    final String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String horaAtualStr = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Histórico de Alertas", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            onPressed: () => _clearHistory(uid),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications_history')
            .where('dataSimples', isEqualTo: hojeStr) // Busca apenas hoje
            .orderBy('horarioFiltro', descending: false) // Ordem cronológica
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Se o erro for falta de índice, o link para criar aparecerá no log do computador
            debugPrint("Erro Firestore: ${snapshot.error}");
            return const Center(child: Text("Erro ao carregar. Verifique o índice ou limpe o histórico."));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtra localmente apenas as notificações que o horário já passou
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String horario = data['horarioFiltro'] ?? "99:99";
            return horario.compareTo(horaAtualStr) <= 0;
          }).toList();

          if (docs.isEmpty) {
            return const Center(
                child: Text("Nenhum alerta disparado ainda hoje.",
                    style: TextStyle(color: Colors.grey))
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final alert = docs[index].data() as Map<String, dynamic>;
              return _buildAlertCard(alert);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final String type = alert['type'] ?? '';
    final bool isWater = type.contains('Água');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isWater ? Colors.blue.shade50 : Colors.orange.shade50,
          child: Icon(
            isWater ? Icons.water_drop : Icons.restaurant_menu,
            color: isWater ? Colors.blue : Colors.orange,
          ),
        ),
        title: Text(alert['title'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['body'] ?? ""),
            const SizedBox(height: 5),
            Text(alert['horarioFiltro'] ?? "",
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _clearHistory(String? uid) async {
    if (uid == null) return;
    var collection = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications_history');
    var snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}