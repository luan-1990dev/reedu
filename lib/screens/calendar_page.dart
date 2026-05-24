import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final DateTime _focusedDay = DateTime.now();

  void _showCommentDialog(String dateId, String? currentComment) {
    final controller = TextEditingController(text: currentComment);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Observação do Dia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLength: 60,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "O que comeu fora do plano?",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1967D2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users').doc(uid).collection('daily_stats').doc(dateId)
                  .set({'off_plan_comment': controller.text}, SetOptions(merge: true));
              if (mounted) Navigator.pop(context);
            },
            child: const Text("SALVAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fundo levemente acinzentado (moderno)
      appBar: AppBar(
        title: const Text("Calendário de Hábitos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, profileSnap) {
          final profile = profileSnap.data?.data() as Map<String, dynamic>?;
          final int totalScheduled = (profile?['meal_schedules'] as List?)?.length ?? 6;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_stats').snapshots(),
            builder: (context, statsSnap) {
              if (!statsSnap.hasData) return const Center(child: CircularProgressIndicator());

              Map<String, dynamic> history = {for (var doc in statsSnap.data!.docs) doc.id: doc.data()};

              return SingleChildScrollView( // Permite que a tela ajuste o tamanho ao conteúdo
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildMonthHeader(),

                    // CARD DO CALENDÁRIO
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: GridView.builder(
                        shrinkWrap: true, // Importante: faz o Grid ocupar apenas o espaço necessário
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day,
                        itemBuilder: (context, index) {
                          int day = index + 1;
                          String dateId = DateFormat('yyyy-MM-dd').format(DateTime(_focusedDay.year, _focusedDay.month, day));
                          var dayData = history[dateId] ?? {};
                          var checks = dayData['meal_checks'] as Map? ?? {};
                          String? comment = dayData['off_plan_comment'];

                          Color bgColor = Colors.white;
                          Color borderColor = Colors.grey.shade100;
                          if (checks.isNotEmpty) {
                            bool onPlan = checks.length >= totalScheduled;
                            bgColor = onPlan ? Colors.green.shade50 : Colors.red.shade50;
                            borderColor = onPlan ? Colors.green.shade200 : Colors.red.shade200;
                          }

                          bool isToday = dateId == DateFormat('yyyy-MM-dd').format(DateTime.now());
                          if (isToday) borderColor = const Color(0xFF1967D2);

                          return GestureDetector(
                            onTap: () => _showCommentDialog(dateId, comment),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: isToday ? 2 : 1),
                              ),
                              child: Stack(
                                children: [
                                  Center(child: Text("$day", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                  if (comment != null && comment.isNotEmpty)
                                    Positioned(right: 4, top: 4, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 25),
                    _buildLegendCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1967D2), Color(0xFF4285F4)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1967D2).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _legendItem("Pendente", Colors.white, Colors.grey.shade200)),
              Expanded(child: _legendItem("No Plano", Colors.green.shade50, Colors.green.shade200)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _legendItem("Fora do Plano", Colors.red.shade50, Colors.red.shade200)),
              Expanded(child: _legendItem("Hoje", Colors.white, const Color(0xFF1967D2))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color bg, Color border) {
    return Row(
      children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
