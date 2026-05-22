import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/database_service.dart';

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isLoading = false;
  bool _showTitle = true;

  final Map<String, List<String>> _metricGroups = {
    'GERAL': ['Peso', 'IDADE', 'ALTURA', 'PESO META'],
    'MEDIDAS PERIFÉRICAS': [
      'Cintura', 'Abdômen', 'Peitoral', 'Quadril',
      'Coxa direita', 'Coxa esquerda', 'Panturrilha dir.', 'Panturrilha esq.'
    ],
    'BIOIMPEDÂNCIA': [
      'IMC', 'PGC (Gordura)', 'PME (Massa Magra)', 'MB (Metabolismo)',
      'IC (Idade Corporal)', 'GV (Gordura Visceral)'
    ],
  };

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _metricGroups.forEach((group, metrics) {
      for (var m in metrics) {
        _controllers[m] = TextEditingController();
      }
    });
    _loadData();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && _showTitle) {
        setState(() => _showTitle = false);
      } else if (_scrollController.offset <= 50 && !_showTitle) {
        setState(() => _showTitle = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controllers.forEach((_, c) => c.dispose());
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final doc = await _db.getLatestAssessment();
    if (doc != null && doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _controllers.forEach((key, controller) {
          if (data.containsKey(key)) {
            controller.text = data[key].toString();
          }
        });
      });
    }
    setState(() => _isLoading = false);
  }

  // --- LÓGICA DE IMPORTAÇÃO HÍBRIDA ---
  Future<void> _importAssessment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        String extractedText = "";
        String filePath = result.files.single.path!;
        String extension = result.files.single.extension?.toLowerCase() ?? "";

        if (extension == 'pdf') {
          final bytes = File(filePath).readAsBytesSync();
          final document = PdfDocument(inputBytes: bytes);
          extractedText = PdfTextExtractor(document).extractText();
          document.dispose();
        } else {
          final inputImage = InputImage.fromFilePath(filePath);
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          extractedText = recognizedText.text;
        }

        _parseAssessmentText(extractedText);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Erro: $e");
    }
  }

  void _parseAssessmentText(String rawText) {
    final text = rawText.replaceAll(',', '.');
    setState(() {
      _controllers.forEach((metric, controller) {
        final pattern = RegExp('$metric' + r'[:\-]*\s*(\d+\.?\d*)', caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null) {
          controller.text = match.group(1)!;
        }
      });
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    Map<String, dynamic> data = {};
    _controllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        data[key] = double.tryParse(controller.text) ?? controller.text;
      }
    });
    await _db.saveAssessment(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avaliação salva com sucesso!"), backgroundColor: Colors.green)
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1967D2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            backgroundColor: primaryBlue,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.document_scanner, color: Colors.white), onPressed: _importAssessment),
              IconButton(icon: const Icon(Icons.done_all, color: Colors.white), onPressed: _save),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showTitle ? 1.0 : 0.0,
                child: const Text('Minha Avaliação', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              background: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue, Color(0xFF163C63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildModernHeader(),
                  const SizedBox(height: 25),
                  _buildCategoryCard('GERAL', Icons.person_pin_rounded, Colors.orange),
                  const SizedBox(height: 15),
                  _buildCategoryCard('MEDIDAS PERIFÉRICAS', Icons.straighten_rounded, Colors.blueGrey),
                  const SizedBox(height: 15),
                  _buildCategoryCard('BIOIMPEDÂNCIA', Icons.monitor_weight_rounded, Colors.blue),
                  const SizedBox(height: 15),
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

  Widget _buildModernHeader() {
    double peso = double.tryParse(_controllers['Peso']?.text ?? "0") ?? 0;
    double meta = double.tryParse(_controllers['PESO META']?.text ?? "0") ?? 0;
    double diff = (peso - meta).abs();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF163C63),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _headerItem("Peso Atual", "${peso.toStringAsFixed(1)}", "kg"),
          Container(width: 1, height: 50, color: Colors.white10),
          _headerItem("Meta", "${meta.toStringAsFixed(1)}", "kg"),
          if (peso > 0 && meta > 0) ...[
            Container(width: 1, height: 50, color: Colors.white10),
            _headerItem("Faltam", diff.toStringAsFixed(1), "kg", color: Colors.orangeAccent),
          ]
        ],
      ),
    );
  }

  Widget _headerItem(String label, String value, String unit, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
              TextSpan(text: " $unit", style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    List<String> metrics = _metricGroups[title] ?? [];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 15),
                Text(title, style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: metrics.map((m) => _buildMetricRow(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label) {
    // Lógica correta de unidades
    String unit = 'cm';
    if (label == 'Peso' || label == 'PESO META') unit = 'kg';
    else if (label == 'IDADE') unit = 'anos';
    else if (label == 'ALTURA') unit = 'm';
    else if (label.contains('Gordura') || label.contains('Massa')) unit = '%';
    else if (label.contains('Metabolismo')) unit = 'kcal';
    else if (label.contains('Visceral')) unit = 'nív';
    else if (label == 'IMC') unit = 'kg/m²';

    Color valueColor = const Color(0xFF374151);
    if (label == 'IMC' || label == 'GV (Gordura Visceral)' || label == 'PGC (Gordura)') {
      double val = double.tryParse(_controllers[label]!.text) ?? 0;
      if (val > 0) valueColor = Colors.redAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14, fontWeight: FontWeight.w500)),
          Row(
            children: [
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _controllers[label],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 16),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Text(unit, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade200, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdealValuesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text("REFERÊNCIAS IDEAIS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _idealItem("IMC", "18.5-25"),
              _idealItem("GORDURA", "8-19%"),
              _idealItem("MASSA", "33-39%"),
              _idealItem("VISCERAL", "1-9"),
            ],
          )
        ],
      ),
    );
  }

  Widget _idealItem(String label, String range) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(range, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }
}