import 'package:flutter/material.dart';

class DietPage extends StatelessWidget {
  const DietPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2F76E9),
          elevation: 0,
          title: const Text('PLANO ALIMENTAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.restaurant), text: 'Refeições'),
              Tab(icon: Icon(Icons.straighten), text: 'Medidas'),
              Tab(icon: Icon(Icons.lightbulb_outline), text: 'Dicas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMealsTab(),
            _buildMeasurementsTab(),
            _buildTipsTab(),
          ],
        ),
      ),
    );
  }

  // ABA 1: REFEIÇÕES
  Widget _buildMealsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAlertCard('UTILIZAR ADOÇANTE STÉVIA 100% OU XILITOL PARA ADOÇAR'),
        const SizedBox(height: 16),
        _buildMealCard('CAFÉ DA MANHÃ', '05:30hrs', [
          'Opção 1: 1 pão francês s/ miolo + 3 ovos mexidos + café + 1 porção de fruta',
          'Opção 2: 2 fatias pão integral + 3 ovos mexidos + café + 1 porção de fruta',
          'Opção 3: 1 pão francês s/ miolo + 70g frango desfiado + café + 1 porção de fruta',
          'Opção 4: 1 crepioca (30g goma + 3 ovos) + 15g requeijão light + café + fruta',
        ], footer: '💡 Tomar 6g de creatina em 50ml de água após o café.'),
        _buildMealCard('LANCHE DA MANHÃ', '09:00hrs', [
          'Opção 1: 30g de whey protein isolado + 200ml de água + 1 banana nanica',
          'Opção 2: 1 pote de iogurte natural integral (170g) + 1 banana nanica',
        ]),
        _buildMealCard('ALMOÇO', '12:30hrs', [
          'Vegetais A: À vontade (Folhas, tomate, brócolis, pepino...)',
          'Vegetais B: 100g (Abóbora, cenoura, vagem, beterraba...)',
          'Proteína: 140g (Carne vermelha, Frango ou Peixe)',
          'Carboidrato: 120g (Arroz ou mandioca/batata/macarrão)',
          'Feijão: 90g (ou Lentilha/Ervilha)',
          'Sobremesa: 1 fruta ou 10g chocolate 60%',
        ], specialInfo: '🥗 Tempere com 1 col. de sobremesa de azeite extra virgem, limão e sal.'),
        _buildMealCard('LANCHE DA TARDE', '16:00 - 18:00hrs', [
          '16:00: 1 porção de fruta (maçã, pêra ou goiaba)',
          '18:00: Pão (francês s/ miolo ou integral) + 1 ovo ou patê de frango + café',
        ]),
        _buildMealCard('JANTAR', '20:00hrs', [
          'Vegetais A: À vontade',
          'Vegetais B: 100g',
          'Proteína: 140g',
          'Carboidrato: 100g (Arroz ou substitutos)',
          'Feijão: 60g',
          'Sobremesa: 1 fruta ou 200ml gelatina diet',
        ]),
      ],
    );
  }

  // ABA 2: GUIA DE MEDIDAS (COLHERES)
  Widget _buildMeasurementsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('GUIA DE COLHERES (MEDIDAS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        _buildSpoonCard('Colher de Servir', 'Maior medida, usada para vegetais e acompanhamentos.', Icons.restaurant),
        _buildSpoonCard('Colher de Sopa', 'Medida padrão para arroz, feijão e proteínas picadas.', Icons.soup_kitchen),
        _buildSpoonCard('Colher de Sobremesa', 'Usada para azeite e porções moderadas.', Icons.icecream),
        _buildSpoonCard('Colher de Chá', 'Medida pequena para sementes ou adoçantes.', Icons.coffee),
        _buildSpoonCard('Colher de Café', 'A menor medida, apenas para toque de sabor.', Icons.coffee_maker),
        _buildSpoonCard('Ponta de Colher', 'Apenas a extremidade da colher (Chá ou Café).', Icons.colorize),
      ],
    );
  }

  // ABA 3: DICAS & ÁGUA
  Widget _buildTipsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWaterScheduleCard(),
        const SizedBox(height: 24),
        const Text('ORIENTAÇÕES GERAIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        _buildTipItem('Respeite os horários, não pule refeições.'),
        _buildTipItem('Use temperos naturais (alho, cebola, ervas).'),
        _buildTipItem('Evite Sazon e temperos prontos (retêm líquido).'),
        _buildTipItem('Dê preferência a alimentos naturais.'),
        _buildTipItem('Evite açúcar refinado e excesso de sal.'),
        _buildTipItem('Consuma carnes magras e aves sem pele.'),
        _buildTipItem('Evite embutidos (presunto, salame, salsicha).'),
        _buildTipItem('Mastigue bem: a digestão começa na boca.'),
        _buildTipItem('Inicie as refeições pela salada para dar saciedade.'),
        _buildTipItem('Beba pelo menos 4 litros de água ao dia.'),
        _buildTipItem('Não perca o foco no final de semana!'),
      ],
    );
  }

  // WIDGETS DE SUPORTE
  Widget _buildAlertCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
      child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)))]),
    );
  }

  Widget _buildMealCard(String title, String time, List<String> options, {String? footer, String? specialInfo}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2F76E9), fontSize: 16)),
              Text(time, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            ]),
            const Divider(),
            ...options.map((opt) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)), Expanded(child: Text(opt, style: const TextStyle(fontSize: 13, color: Colors.black87)))]))),
            if (specialInfo != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(specialInfo, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
            if (footer != null) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Text(footer, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
          ],
        ),
      ),
    );
  }

  Widget _buildSpoonCard(String title, String desc, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(icon, color: Colors.blue)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildWaterScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)]), borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.water_drop, color: Colors.white), SizedBox(width: 10), Text('AGENDA DE ÁGUA (4L TOTAL)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          _waterRow('Morning', '07:00 - 12:00', '2 Garrafas (1L)'),
          _waterRow('Afternoon 1', '13:00 - 15:00', '2 Garrafas (1L)'),
          _waterRow('Afternoon 2', '15:30 - 18:30', '2 Garrafas (1L)'),
          _waterRow('Night', '18:30 - 22:00', '2 Garrafas (1L)'),
        ],
      ),
    );
  }

  Widget _waterRow(String period, String time, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
      ]),
    );
  }
}
