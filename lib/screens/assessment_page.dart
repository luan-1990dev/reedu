import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _isEditing = false;
  bool _isLoading = false;

  final List<String> _fields = [
    'NOME', 'IDADE', 'ALTURA', 'PESO META',
    'Peso', 'Braço direito', 'Braço esquerdo', 'Cintura', 'Abdomên',
    'Peitoral', 'Quadril', 'Coxa direita', 'Coxa esquerda',
    'Panturrilha direita', 'Panturrilha esquerda',
    'IMC', 'PGC', 'PME', 'MB', 'IC', 'GV',
    'Tricipital', 'Subescapular', 'Axilar média', 'Supra-ilíaca',
    'Peitoral (mm)', 'Abdominal (mm)', 'Coxa (mm)'
  ];

  @override
  void initState() {
    super.initState();
    for (var field in _fields) {
      _controllers[field] = TextEditingController();
      _focusNodes[field] = FocusNode();
      _focusNodes[field]!.addListener(() => setState(() {}));
    }
    _loadAllData();
  }

  // Lógica de carregamento corrigida
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Tenta buscar os dados do perfil e a última avaliação
      final userSnap = await _db.userProfileStream.first;
      final lastEval = await _db.getLatestAssessment();

      if (mounted) {
        setState(() {
          // 1. Carrega dados do Perfil (Nome, Idade, Altura, Meta)
          if (userSnap.exists) {
            final u = userSnap.data() as Map<String, dynamic>;
            _controllers['NOME']!.text = (u['nickname'] ?? u['name'] ?? '').toString();
            _controllers['IDADE']!.text = (u['age'] ?? '').toString();
            _controllers['ALTURA']!.text = (u['height'] ?? '').toString();
            _controllers['PESO META']!.text = (u['targetWeight'] ?? '').toString();
          }

          // 2. Carrega dados da última avaliação salva (Peso, Medidas, etc)
          if (lastEval != null && lastEval.exists) {
            final e = lastEval.data() as Map<String, dynamic>;
            for (var f in _fields) {
              // Só preenche se o campo estiver vazio (prioriza dados do perfil para os 4 primeiros)
              if (e.containsKey(f) && _controllers[f]!.text.isEmpty) {
                _controllers[f]!.text = e[f].toString();
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint("ERRO AO CARREGAR AVALIAÇÃO: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var f in _fields) {
      _controllers[f]?.dispose();
      _focusNodes[f]?.dispose();
    }
    super.dispose();
  }

  Color _getValueColor(String key, String value) {
    double? val = double.tryParse(value.replaceAll(',', '.'));
    if (val == null) return Colors.black87;
    switch (key) {
      case 'IMC':
        if (val > 30 || val < 17) return Colors.red;
        if (val > 25) return Colors.orange;
        return Colors.green.shade700;
      case 'PGC':
        if (val > 25) return Colors.red;
        if (val > 20) return Colors.orange;
        return Colors.green.shade700;
      case 'PME':
        if (val < 30) return Colors.red;
        if (val < 33.3) return Colors.orange;
        return Colors.green.shade700;
      case 'GV':
        if (val > 12) return Colors.red;
        if (val > 9) return Colors.orange;
        return Colors.green.shade700;
      default:
        return Colors.black87;
    }
  }

  Future<void> _importPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf']
      );
      if (result != null) {
        setState(() => _isLoading = true);
        final bytes = File(result.files.single.path!).readAsBytesSync();
        final document = PdfDocument(inputBytes: bytes);
        String text = PdfTextExtractor(document).extractText();
        document.dispose();

        debugPrint("================ TEXTO EXTRAÍDO ================");
        debugPrint(text);
        debugPrint("================================================");

        _smartParse(text);
        setState(() { _isLoading = false; _isEditing = true; });
      }
    } catch (e) {
      debugPrint("Erro no PDF: $e");
      setState(() => _isLoading = false);
    }
  }

  void _smartParse(String rawText) {
    // Normalização agressiva para ignorar quebras de linha entre rótulo e valor
    final text = rawText.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');

    String? findNum(List<String> keys) {
      for (var key in keys) {
        final pattern = RegExp('$key' + r'\s*[:\-]*\s*([\d+[\.,]?\d*)', caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
          return match.group(1)!.replaceAll(',', '.');
        }
      }
      return null;
    }

    String? findName() {
      final pattern = RegExp(r'NOME:\s*(.*?)(?=\s*IDADE:|$)', caseSensitive: false);
      final match = pattern.firstMatch(text);
      return match?.group(1)?.trim();
    }

    setState(() {
      _controllers['NOME']!.text = findName() ?? _controllers['NOME']!.text;
      _controllers['Peso']!.text = findNum(['Peso', 'Massa Corporal', 'Corporal']) ?? _controllers['Peso']!.text;
      _controllers['IDADE']!.text = findNum(['IDADE', 'Anos', 'Idade']) ?? _controllers['IDADE']!.text;
      _controllers['ALTURA']!.text = findNum(['ALTURA', 'Estatura', 'Altura']) ?? _controllers['ALTURA']!.text;
      _controllers['PESO META']!.text = findNum(['PESO META', 'META']) ?? _controllers['PESO META']!.text;

      _controllers['IMC']!.text = findNum(['IMC']) ?? _controllers['IMC']!.text;
      _controllers['PGC']!.text = findNum(['PGC', 'Gordura']) ?? _controllers['PGC']!.text;
      _controllers['PME']!.text = findNum(['PME', 'Massa Magra']) ?? _controllers['PME']!.text;
      _controllers['MB']!.text = findNum(['MB', 'Metabolismo', 'TMB']) ?? _controllers['MB']!.text;
      _controllers['IC']!.text = findNum(['IC', 'Idade Corporal']) ?? _controllers['IC']!.text;
      _controllers['GV']!.text = findNum(['GV', 'Visceral']) ?? _controllers['GV']!.text;

      _controllers['Tricipital']!.text = findNum(['Tricipital']) ?? _controllers['Tricipital']!.text;
      _controllers['Subescapular']!.text = findNum(['Subescapular']) ?? _controllers['Subescapular']!.text;
      _controllers['Axilar média']!.text = findNum(['Axilar média', 'Axilar']) ?? _controllers['Axilar média']!.text;
      _controllers['Supra-ilíaca']!.text = findNum(['Supra-ilíaca', 'Supra']) ?? _controllers['Supra-ilíaca']!.text;
      _controllers['Peitoral (mm)']!.text = findNum(['Peitoral']) ?? _controllers['Peitoral (mm)']!.text;
      _controllers['Abdominal (mm)']!.text = findNum(['Abdominal']) ?? _controllers['Abdominal (mm)']!.text;
      _controllers['Coxa (mm)']!.text = findNum(['Coxa']) ?? _controllers['Coxa (mm)']!.text;
    });
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, dynamic> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    await _db.saveAssessment(data);
    setState(() { _isEditing = false; _isLoading = false; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados salvos!'), backgroundColor: Colors.teal));
  }

  void _showEvolutionCharts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Color(0xFF3B82F6), size: 20),
                SizedBox(width: 10),
                Text('MINHA EVOLUÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF475569))),
              ],
            ),
            const SizedBox(height: 25),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.weightHistory,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("Sem dados para exibir"));

                  List<FlSpot> weightSpots = [];
                  List<FlSpot> fatSpots = [];

                  for (int i = 0; i < docs.length; i++) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    double w = data.containsKey('Peso') ? (double.tryParse(data['Peso'].toString()) ?? 0) : 0;
                    double f = data.containsKey('PGC') ? (double.tryParse(data['PGC'].toString()) ?? 0) : 0;
                    weightSpots.add(FlSpot(i.toDouble(), w));
                    fatSpots.add(FlSpot(i.toDouble(), f));
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildChartCard('Evolução de Peso (kg)', weightSpots, Colors.blue),
                      const SizedBox(height: 20),
                      _buildChartCard('Gordura Corporal (%)', fatSpots, Colors.redAccent),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, List<FlSpot> spots, Color color) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 15),
          Expanded(
            child: LineChart(LineChartData(
              lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
                  )
              ),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: color.withOpacity(0.05))
                )
              ],
            )),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF00008B);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            backgroundColor: darkBlue,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _importPDF),
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.white, size: 28),
                onPressed: () => _isEditing ? _saveData() : setState(() => _isEditing = true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF1A1A9E), darkBlue],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter
                    )
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: _buildHeader(),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildEvolutionButton(darkBlue),
                  const SizedBox(height: 25),
                  _buildSection('MEDIDAS PERIFÉRICAS', Icons.straighten, [
                    _buildHighlightedRow('Peso', 'Peso', 'kg', 'Seu peso atual'),
                    _buildHighlightedRow('Braço direito', 'Braço direito', 'cm', 'Circunferência do braço'),
                    _buildHighlightedRow('Braço esquerdo', 'Braço esquerdo', 'cm', 'Circunferência do braço'),
                    _buildHighlightedRow('Cintura', 'Cintura', 'cm', 'Medida na altura do umbigo'),
                    _buildHighlightedRow('Abdomên', 'Abdomên', 'cm', 'Medida abdominal'),
                    _buildHighlightedRow('Quadril', 'Quadril', 'cm', 'Medida glútea'),
                    _buildHighlightedRow('Peitoral', 'Peitoral', 'cm', 'Medida do peito'),
                    _buildHighlightedRow('Coxa direita', 'Coxa direita', 'cm', 'Medida da coxa'),
                    _buildHighlightedRow('Panturrilha dir.', 'Panturrilha direita', 'cm', 'Medida da panturrilha'),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('BIOIMPEDÂNCIA', Icons.analytics_outlined, [
                    _buildHighlightedRow('IMC', 'IMC', 'kg/m²', 'Índice de Massa Corporal'),
                    _buildHighlightedRow('PGC (Gordura)', 'PGC', '%', 'Gordura Corporal'),
                    _buildHighlightedRow('PME (Massa Magra)', 'PME', '%', 'Massa Muscular'),
                    _buildHighlightedRow('MB (Metabolismo)', 'MB', 'kcal', 'Taxa Metabólica'),
                    _buildHighlightedRow('IC (Idade Corporal)', 'IC', 'anos', 'Idade Biológica'),
                    _buildHighlightedRow('GV (Gordura Visceral)', 'GV', 'nível', 'Gordura nos Órgãos'),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('DOBRAS CUTÂNEAS', Icons.layers_outlined, [
                    _buildHighlightedRow('Tricipital', 'Tricipital', 'mm', 'Dobra do tríceps'),
                    _buildHighlightedRow('Subescapular', 'Subescapular', 'mm', 'Dobra abaixo da escápula'),
                    _buildHighlightedRow('Axilar média', 'Axilar média', 'mm', 'Dobra na linha axilar'),
                    _buildHighlightedRow('Supra-ilíaca', 'Supra-ilíaca', 'mm', 'Dobra acima da crista ilíaca'),
                    _buildHighlightedRow('Peitoral', 'Peitoral (mm)', 'mm', 'Dobra do peito'),
                    _buildHighlightedRow('Abdominal', 'Abdominal (mm)', 'mm', 'Dobra do abdômen'),
                    _buildHighlightedRow('Coxa', 'Coxa (mm)', 'mm', 'Dobra da coxa'),
                  ]),
                  const SizedBox(height: 20),
                  _buildIdealValuesCard(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _isEditing
            ? _headerTextField('NOME')
            : Text(_controllers['NOME']!.text.isEmpty ? "Usuário" : _controllers['NOME']!.text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _editableChip(Icons.cake, 'IDADE', ' anos', "Sua idade atual"),
            const SizedBox(width: 8),
            _editableChip(Icons.height, 'ALTURA', ' m', "Sua altura"),
            const SizedBox(width: 8),
            _editableChip(Icons.flag, 'PESO META', ' kg', "Seu objetivo", prefix: 'Meta: '),
          ],
        ),
      ],
    );
  }

  Widget _headerTextField(String key) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _controllers[key],
        focusNode: _focusNodes[key],
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
        ),
      ),
    );
  }

  Widget _editableChip(IconData icon, String key, String suffix, String tooltip, {String prefix = ''}) {
    bool hasFocus = _focusNodes[key]?.hasFocus ?? false;
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasFocus ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasFocus ? Colors.white : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
            _isEditing
                ? IntrinsicWidth(child: TextField(
              controller: _controllers[key],
              focusNode: _focusNodes[key],
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none),
            ))
                : Text('$prefix${_controllers[key]!.text}$suffix', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedRow(String label, String key, String suffix, String tooltip) {
    bool hasFocus = _focusNodes[key]?.hasFocus ?? false;
    String value = _controllers[key]?.text ?? '';
    Color valueColor = _getValueColor(key, value);

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasFocus ? Colors.blue.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasFocus ? Colors.blue.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: hasFocus ? Colors.blue.shade700 : Colors.black54, fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal)),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _controllers[key],
                focusNode: _focusNodes[key],
                enabled: _isEditing,
                textAlign: TextAlign.end,
                keyboardType: TextInputType.number,
                style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
                decoration: InputDecoration(suffixText: ' $suffix', border: InputBorder.none, isDense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: const Color(0xFF3B82F6)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
        children: [Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(children: children))],
      ),
    );
  }

  Widget _buildIdealValuesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF00695C), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Row(children: [Icon(Icons.star, color: Colors.white, size: 18), SizedBox(width: 10), Text('VALORES IDEAIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _idealItem('IMC', '18.5-25'),
              _idealItem('PGC', '8-19.9'),
              _idealItem('PME', '33.3-39.9'),
              _idealItem('GV', '5-9'),
            ],
          )
        ],
      ),
    );
  }

  Widget _idealItem(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    ]);
  }

  Widget _buildEvolutionButton(Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showEvolutionCharts,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_graph, color: Colors.white), SizedBox(width: 12), Text('VER MINHA EVOLUÇÃO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1))]),
          ),
        ),
      ),
    );
  }
}