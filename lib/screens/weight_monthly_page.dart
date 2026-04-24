import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class WeightMonthlyPage extends StatelessWidget {
  const WeightMonthlyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService db = DatabaseService();
    const Color primaryColor = Color(0xFF00695C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Oscilação Mensal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.weightHistory,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Sem dados históricos"));

          List<FlSpot> spots = [];
          List<String> dates = [];

          // Pega os últimos 30 registros (ou todos se houver menos de 30)
          int startIndex = docs.length > 30 ? docs.length - 30 : 0;
          int chartIndex = 0;

          for (int i = startIndex; i < docs.length; i++) {
            var weight = double.tryParse(docs[i]['Peso'].toString().replaceAll(',', '.')) ?? 0;
            spots.add(FlSpot(chartIndex.toDouble(), weight));

            var timestamp = docs[i]['timestamp'] as Timestamp?;
            dates.add(timestamp != null ? DateFormat('dd/MM').format(timestamp.toDate()) : '');
            chartIndex++;
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                  child: LineChart(LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5, // Mostra data de 5 em 5 dias para não poluir
                          getTitlesWidget: (val, _) => Text(dates[val.toInt()], style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: primaryColor,
                        barWidth: 4,
                        dotData: const FlDotData(show: true),
                      )
                    ],
                  )),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Este gráfico exibe o progresso dos últimos 30 registros.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          );
        },
      ),
    );
  }
}