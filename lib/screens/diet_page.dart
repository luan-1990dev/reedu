import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  final DatabaseService _db = DatabaseService();
  bool _isEditing = false;
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {
    'CAFÉ DA MANHÃ': TextEditingController(),
    'LANCHE DA MANHÃ': TextEditingController(),
    'ALMOÇO': TextEditingController(),
    'LANCHE DA TARDE': TextEditingController(),
    'JANTAR': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadDietData();
  }

  Future<void> _loadDietData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('full_diet')) {
        final Map<String, dynamic> saved = doc.data()!['full_diet'];
        setState(() {
          saved.forEach((key, value) {
            if (_controllers.containsKey(key)) {
              _controllers[key]!.text = value.toString();
            }
          });
        });
      } else {
        // Valores padrão iniciais se não houver nada salvo
        _controllers['CAFÉ DA MANHÃ']!.text = 'Opção 1: 1 pão francês s/ miolo + 3 ovos mexidos + café + 1 porção de fruta\nOpção 2: 2 fatias pão integral + 3 ovos mexidos + café + 1 porção de fruta';
        _controllers['LANCHE DA MANHÃ']!.text = 'Opção 1: 30g de whey protein isolado + 200ml de água + 1 banana nanica\nOpção 2: 1 pote de iogurte natural integral (170g) + 1 banana nanica';
        _controllers['ALMOÇO']!.text = 'Vegetais A: À vontade\nVegetais B: 100g\nProteína: 140g\nCarboidrato: 120g\nFeijão: 90g\nSobremesa: 1 fruta ou 10g chocolate 60%';
        _controllers['LANCHE DA TARDE']!.text = '16:00: 1 porção de fruta (maçã, pêra ou goiaba)\n18:00: Pão + 1 ovo ou patê de frango + café';
        _controllers['JANTAR']!.text = 'Vegetais A: À vontade\nVegetais B: 100g\nProteína: 140g\nCarboidrato: 100g\nFeijão: 60g\nSobremesa: 1 fruta ou 200ml gelatina diet';
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, String> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'full_diet': data,
        }, SetOptions(merge: true));
        if (mounted) {
          setState(() { _isEditing = false; _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Plano Alimentar atualizado!', textAlign: TextAlign.center),
              backgroundColor: Colors.teal.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryOceanGreen = Color(0xFF004D40);
    const Color bgSoft = Color(0xFFF8FAFC);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgSoft,
        appBar: AppBar(
          backgroundColor: primaryOceanGreen,
          elevation: 0,
          title: const Text('PLANO ALIMENTAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, letterSpacing: 1.2)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          actions: [
            if (!_isEditing) 
              IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => setState(() => _isEditing = true))
            else 
              IconButton(
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.check, color: Colors.white, size: 28), 
                onPressed: _isLoading ? null : _saveData
              ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'REFEIÇÕES'),
              Tab(text: 'MEDIDAS'),
              Tab(text: 'DICAS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMealsTab(primaryOceanGreen),
            _buildMeasurementsTab(),
            _buildTipsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsTab(Color themeColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildInfoCard('UTILIZAR ADOÇANTE STÉVIA 100% OU XILITOL PARA ADOÇAR', Icons.info_outline, Colors.orange.shade800),
        const SizedBox(height: 20),
        _buildEditableMealCard('CAFÉ DA MANHÃ', '05:30', themeColor),
        _buildEditableMealCard('LANCHE DA MANHÃ', '09:00', themeColor),
        _buildEditableMealCard('ALMOÇO', '12:30', themeColor),
        _buildEditableMealCard('LANCHE DA TARDE', '16:00 - 18:00', themeColor),
        _buildEditableMealCard('JANTAR', '20:00', themeColor),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEditableMealCard(String title, String time, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 14)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 10))),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isEditing 
                ? TextField(
                    controller: _controllers[title],
                    maxLines: null,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Digite os detalhes da refeição...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  )
                : Text(
                    _controllers[title]!.text.isEmpty ? 'Nenhuma informação cadastrada.' : _controllers[title]!.text,
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('GUIA DE MEDIDAS (COLHERES)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        _buildSpoonCard('Colher de Servir', 'Maior medida, usada para vegetais.', Icons.restaurant),
        _buildSpoonCard('Colher de Sopa', 'Arroz, feijão e proteínas picadas.', Icons.soup_kitchen),
        _buildSpoonCard('Colher de Sobremesa', 'Azeite e porções moderadas.', Icons.icecream),
        _buildSpoonCard('Colher de Chá', 'Sementes ou adoçantes.', Icons.coffee),
        _buildSpoonCard('Colher de Café', 'Toques de sabor.', Icons.coffee_maker),
      ],
    );
  }

  Widget _buildTipsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildWaterPrecisionCard(),
        const SizedBox(height: 30),
        const Text('ORIENTAÇÕES GERAIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
        const SizedBox(height: 15),
        _buildTipItem('Respeite os horários, não pule refeições.'),
        _buildTipItem('Use temperos naturais (alho, cebola, ervas).'),
        _buildTipItem('Evite açúcar refinado e excesso de sal.'),
        _buildTipItem('Consuma carnes magras e aves sem pele.'),
        _buildTipItem('Mastigue bem: a digestão começa na boca.'),
        _buildTipItem('Beba pelo menos 4 litros de água ao dia.'),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInfoCard(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 12), Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)))]),
    );
  }

  Widget _buildSpoonCard(String title, String desc, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(icon, color: Colors.blue, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildWaterPrecisionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00796B), Color(0xFF004D40)]), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.water_drop, color: Colors.white, size: 20), SizedBox(width: 10), Text('METAS DE ÁGUA (4L DIÁRIOS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]),
          const SizedBox(height: 16),
          _waterRow('07:00 - 12:00', '1 Litro'),
          _waterRow('13:00 - 15:00', '1 Litro'),
          _waterRow('15:00 - 18:30', '1 Litro'),
          _waterRow('18:30 - 22:00', '1 Litro'),
        ],
      ),
    );
  }

  Widget _waterRow(String time, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline, color: Colors.teal, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4))),
      ]),
    );
  }
}
