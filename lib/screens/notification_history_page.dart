import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationHistoryPage extends StatelessWidget {
  const NotificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    // Filtros de tempo para a regra de negócio
    final String hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String horaAtualStr = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Histórico de Alertas",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: "Limpar tudo",
            onPressed: () => _clearHistory(uid, context),
          )
        ],
      ),
      body: uid == null
          ? const Center(child: Text("Usuário não logado"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications_history')
            .where('dataSimples', isEqualTo: hojeStr) // Filtra apenas hoje
            .orderBy('horarioFiltro', descending: false) // Ordem cronológica
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Erro ao carregar histórico. Verifique se o índice composto foi criado no Firebase Console.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Lógica de Filtro local: Remove alertas agendados para horários futuros
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String horarioNotificacao = data['horarioFiltro'] ?? "99:99";
            return horarioNotificacao.compareTo(horaAtualStr) <= 0;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    "Nenhum alerta disparado ainda hoje.",
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
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
    final Color themeColor = _getThemeColor(type);
    final IconData icon = _getIcon(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: themeColor.withOpacity(0.1),
          child: Icon(icon, color: themeColor, size: 20),
        ),
        title: Text(
          alert['title'] ?? "Alerta",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              alert['body'] ?? "",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  alert['horarioFiltro'] ?? "--:--",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearHistory(String? uid, BuildContext context) async {
    if (uid == null) return;

    // Confirmação antes de apagar
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Limpar Histórico?"),
        content: const Text("Isso apagará todos os registros de hoje."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("LIMPAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      var collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications_history');

      var snapshots = await collection.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
    }
  }

  Color _getThemeColor(String type) {
    if (type.contains('Água')) return Colors.blue;
    if (type.contains('Refeição')) return Colors.orange;
    if (type.contains('Resumo')) return Colors.purple;
    return Colors.teal;
  }

  IconData _getIcon(String type) {
    if (type.contains('Água')) return Icons.water_drop;
    if (type.contains('Refeição')) return Icons.restaurant;
    if (type.contains('Resumo')) return Icons.bar_chart;
    return Icons.notifications;
  }
}