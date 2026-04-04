import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/database_service.dart';

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final DatabaseService _db = DatabaseService();
  bool _isEditing = false;
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {
    'NOME': TextEditingController(text: 'Luan Oliveira Inácio'),
    'IDADE': TextEditingController(text: '35'),
    'ALTURA': TextEditingController(text: '1.82'),
    'PESO META': TextEditingController(text: '86'),
    'Peso': TextEditingController(text: '96.3'),
    'Braço direito': TextEditingController(text: '34'),
    'Braço esquerdo': TextEditingController(text: '34'),
    'Cintura': TextEditingController(text: '99'),
    'Abdomên': TextEditingController(text: '103'),
    'Peitoral': TextEditingController(text: '108'),
    'Quadril': TextEditingController(text: '104'),
    'Coxa direita': TextEditingController(text: '49'),
    'Coxa esquerda': TextEditingController(text: '50'),
    'Panturrilha direita': TextEditingController(text: '35'),
    'Panturrilha esquerda': TextEditingController(text: '35'),
    'IMC': TextEditingController(text: '29.2'),
    'PGC': TextEditingController(text: '31.7'),
    'PME': TextEditingController(text: '31.0'),
    'MB': TextEditingController(text: '1958'),
    'IC': TextEditingController(text: '64'),
    'GV': TextEditingController(text: '12'),
    'Triciptal': TextEditingController(text: '20'),
    'Subescapular': TextEditingController(text: '30'),
    'Axilar média': TextEditingController(text: '40'),
    'Suprailíaca': TextEditingController(text: '45'),
    'Peitoral Pregas': TextEditingController(text: '12'),
    'Abdominal': TextEditingController(text: '45'),
    'Coxa Pregas': TextEditingController(text: '13'),
  };

  @override
  void dispose() {
    for (var c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _importPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        
        final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
        String text = PdfTextExtractor(document).extractText();
        document.dispose();

        _smartParse(text);

        if (mounted) {
          setState(() => _isLoading = false);
          _isEditing = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF analisado com sucesso! Verifique os campos destacados.', textAlign: TextAlign.center),
              backgroundColor: Colors.teal.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na leitura inteligente: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _smartParse(String rawText) {
    // Normaliza o texto para facilitar a busca (remove excesso de espaços e padroniza quebras)
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ');

    // Função interna aperfeiçoada com RegExp resiliente
    String? find(List<String> keys) {
      for (var key in keys) {
        // Busca a palavra-chave seguida opcionalmente de : ou - e captura o número (aceita 96,3 ou 96.3)
        final pattern = RegExp('$key[:\\s\\-]*([\\d+[\\.,]?\\d*)', caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.replaceAll(',', '.'); // Padroniza para ponto decimal
        }
      }
      return null;
    }

    setState(() {
      // Mapeamento com Sinônimos para maior precisão
      _controllers['Peso']?.text = find(['Peso', 'Massa Corporal', 'Peso Atual']) ?? _controllers['Peso']!.text;
      _controllers['IMC']?.text = find(['IMC', 'Índice de Massa Corporal']) ?? _controllers['IMC']!.text;
      _controllers['PGC']?.text = find(['PGC', 'Gordura Corporal', '% Gordura', 'Gordura']) ?? _controllers['PGC']!.text;
      _controllers['PME']?.text = find(['PME', 'Massa Magra', 'Massa Muscular', '% Muscular']) ?? _controllers['PME']!.text;
      _controllers['Cintura']?.text = find(['Cintura', 'Circunferência Abdominal']) ?? _controllers['Cintura']!.text;
      _controllers['Quadril']?.text = find(['Quadril']) ?? _controllers['Quadril']!.text;
      _controllers['MB']?.text = find(['MB', 'Metabolismo Basal', 'TMB', 'Taxa Metabólica']) ?? _controllers['MB']!.text;
      _controllers['GV']?.text = find(['GV', 'Gordura Visceral', 'Nível Visceral']) ?? _controllers['GV']!.text;
      _controllers['IC']?.text = find(['IC', 'Idade Corporal', 'Idade Biológica']) ?? _controllers['IC']!.text;
      
      // Pregas Cutâneas
      _controllers['Abdominal']?.text = find(['Abdominal', 'Pregas Abdominal']) ?? _controllers['Abdominal']!.text;
      _controllers['Triciptal']?.text = find(['Triciptal', 'Tríceps']) ?? _controllers['Triciptal']!.text;
      _controllers['Subescapular']?.text = find(['Subescapular']) ?? _controllers['Subescapular']!.text;
    });
  }

  Color _getStatusColor(String key, String value) {
    double? val = double.tryParse(value);
    if (val == null) return Colors.black87;
    switch (key) {
      case 'IMC':
        if (val < 18.5) return Colors.orange;
        if (val <= 25.0) return Colors.green.shade700;
        return Colors.red;
      case 'PGC':
        if (val < 8.0) return Colors.orange;
        if (val <= 19.9) return Colors.green.shade700;
        return Colors.red;
      case 'PME':
        if (val < 33.3) return Colors.orange;
        if (val <= 39.9) return Colors.green.shade700;
        return Colors.red;
      case 'GV':
        if (val < 5.0) return Colors.orange;
        if (val <= 9.0) return Colors.green.shade700;
        return Colors.red;
      default:
        return Colors.black87;
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, dynamic> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    try {
      await _db.saveAssessment(data);
      if (mounted) {
        setState(() { _isEditing = false; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Avaliação salva com sucesso!', textAlign: TextAlign.center),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e', textAlign: TextAlign.center), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1967D2);
    const Color bgSoft = Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: bgSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            backgroundColor: primaryBlue,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _importPDF, tooltip: 'Importação Inteligente'),
              if (!_isEditing) IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => setState(() => _isEditing = true))
              else IconButton(icon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, color: Colors.white, size: 30), onPressed: _isLoading ? null : _saveData),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Minha Avaliação', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryBlue, Color(0xFF4285F4)]),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _buildHeaderInfoModern(),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernSection('MEDIDAS PERIFÉRICAS', Icons.straighten, [
                    _buildModernRow('Peso', 'Peso', suffix: ' kg'),
                    _buildModernRow('Braço direito', 'Braço direito', suffix: ' cm'),
                    _buildModernRow('Braço esquerdo', 'Braço esquerdo', suffix: ' cm'),
                    _buildModernRow('Cintura', 'Cintura', suffix: ' cm'),
                    _buildModernRow('Abdomên', 'Abdomên', suffix: ' cm'),
                    _buildModernRow('Peitoral', 'Peitoral', suffix: ' cm'),
                    _buildModernRow('Quadril', 'Quadril', suffix: ' cm'),
                    _buildModernRow('Coxa direita', 'Coxa direita', suffix: ' cm'),
                    _buildModernRow('Coxa esquerda', 'Coxa esquerda', suffix: ' cm'),
                    _buildModernRow('Panturrilha dir.', 'Panturrilha direita', suffix: ' cm'),
                    _buildModernRow('Panturrilha esq.', 'Panturrilha esquerda', suffix: ' cm'),
                  ]),
                  const SizedBox(height: 20),
                  _buildModernSection('BIOIMPEDÂNCIA', Icons.analytics_outlined, [
                    _buildModernRow('IMC', 'IMC', suffix: ' kg/m²'),
                    _buildModernRow('PGC (Gordura)', 'PGC', suffix: ' %'),
                    _buildModernRow('PME (Massa Magra)', 'PME', suffix: ' %'),
                    _buildModernRow('MB (Metabolismo)', 'MB', suffix: ' kcal'),
                    _buildModernRow('IC (Idade Corporal)', 'IC', suffix: ' anos'),
                    _buildModernRow('GV (Gordura Visceral)', 'GV', suffix: ' nível'),
                  ]),
                  const SizedBox(height: 20),
                  _buildModernSection('PREGAS CUTÂNEAS', Icons.fingerprint, [
                    _buildModernRow('Triciptal', 'Triciptal', suffix: ' mm'),
                    _buildModernRow('Subescapular', 'Subescapular', suffix: ' mm'),
                    _buildModernRow('Axilar média', 'Axilar média', suffix: ' mm'),
                    _buildModernRow('Suprailíaca', 'Suprailíaca', suffix: ' mm'),
                    _buildModernRow('Peitoral', 'Peitoral Pregas', suffix: ' mm'),
                    _buildModernRow('Abdominal', 'Abdominal', suffix: ' mm'),
                    _buildModernRow('Coxa', 'Coxa Pregas', suffix: ' mm'),
                  ]),
                  const SizedBox(height: 20),
                  _buildIdealValuesCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoModern() {
    return _isEditing 
      ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _controllers['NOME'], style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'NOME', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)))),
              Row(
                children: [
                  Expanded(child: TextField(controller: _controllers['IDADE'], style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'IDADE', labelStyle: TextStyle(color: Colors.white70)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _controllers['ALTURA'], style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'ALTURA', labelStyle: TextStyle(color: Colors.white70)))),
                ],
              )
            ],
          ),
        )
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_controllers['NOME']!.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeaderBadge(Icons.cake, '${_controllers['IDADE']!.text} anos'),
                const SizedBox(width: 12),
                _buildHeaderBadge(Icons.height, '${_controllers['ALTURA']!.text} m'),
                const SizedBox(width: 12),
                _buildHeaderBadge(Icons.flag, 'Meta: ${_controllers['PESO META']!.text}kg'),
              ],
            ),
          ],
        );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [Icon(icon, size: 14, color: Colors.white70), const SizedBox(width: 4), Text(text, style: const TextStyle(color: Colors.white, fontSize: 12))]),
    );
  }

  Widget _buildModernSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: Colors.blue, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildModernRow(String label, String key, {required String suffix}) {
    String value = _controllers[key]?.text ?? '';
    Color statusColor = _getStatusColor(key, value);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          _isEditing 
            ? SizedBox(width: 80, child: TextField(controller: _controllers[key], textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor), decoration: InputDecoration(suffixText: suffix, isDense: true)))
            : Text('$value$suffix', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildIdealValuesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Row(children: [Icon(Icons.star, color: Colors.white, size: 18), SizedBox(width: 8), Text('VALORES IDEAIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIdealItem('IMC', '18.5-25'),
              _buildIdealItem('PGC', '8-19.9'),
              _buildIdealItem('PME', '33.3-39.9'),
              _buildIdealItem('GV', '5-9'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildIdealItem(String label, String range) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), Text(range, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]);
  }
}
