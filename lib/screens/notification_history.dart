import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationHistoryPage extends StatelessWidget {
  const NotificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Histórico de Alertas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // Opção para limpar o histórico
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _clearHistory(uid),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications_history')
            .orderBy('horarioFiltro', descending: false)
            .limit(50) // Limita as últimas 50
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Nenhuma notificação enviada recentemente.",
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();
              final String type = data['type'] ?? 'Geral';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColor(type).withOpacity(0.1),
                    child: Icon(_getIcon(type), color: _getColor(type), size: 20),
                  ),
                  title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['body'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 5),
                      Text(date != null ? DateFormat('dd/MM - HH:mm').format(date) : '',
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _clearHistory(String uid) async {
    final collection = FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications_history');
    final snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }

  Color _getColor(String type) {
    if (type.contains('Água')) return Colors.blue;
    if (type.contains('Refeição')) return Colors.orange;
    return Colors.teal;
  }

  IconData _getIcon(String type) {
    if (type.contains('Água')) return Icons.water_drop;
    if (type.contains('Refeição')) return Icons.restaurant;
    return Icons.notifications;
  }
}