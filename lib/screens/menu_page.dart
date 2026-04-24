import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;
  bool _isEditing = false;

  final Map<String, TextEditingController> _controllers = {
    'Café da Manhã': TextEditingController(),
    'Lanche da Manhã': TextEditingController(),
    'Almoço': TextEditingController(),
    'Lanche da Tarde 1': TextEditingController(),
    'Lanche da Tarde 2': TextEditingController(),
    'Jantar': TextEditingController(),
    'Observações': TextEditingController(),
  };

  final List<String> _mealOrder = [
    'Café da Manhã',
    'Lanche da Manhã',
    'Almoço',
    'Lanche da Tarde 1',
    'Lanche da Tarde 2',
    'Jantar'
  ];

  final Map<String, List<String>> _mealOptions = {
    'Café da Manhã': [
      '1 pão francês s/ miolo + 3 ovos mexidos + café + fruta',
      '2 fatias pão integral + 3 ovos mexidos + café + fruta',
      '1 pão francês s/ miolo + 70g frango desfiado + café + fruta',
      '1 crepioca (30g goma + 3 ovos) + 15g requeijão light + café + fruta',
    ],
    'Lanche da Manhã': [
      '30g de whey protein isolado + 200ml de água + 1 banana nanica',
      '1 pote de iogurte natural integral (170g) + 1 banana nanica',
    ],
    'Almoço': [
      'Arroz (120g) + Feijão (90g) + Carne Magra (140g) + Vegetais',
      'Macarrão Integral (120g) + Carne Magra (140g) + Vegetais',
      'Batata Doce (120g) + Carne Magra (140g) + Vegetais',
      'Mandioca (120g) + Carne Magra (140g) + Vegetais',
    ],
    'Lanche da Tarde 1': [
      '1 porção de fruta (maçã, pêra ou goiaba)',
    ],
    'Lanche da Tarde 2': [
      '1 pão francês s/ miolo + 1 ovo mexido + café',
      '2 fatias pão integral + 1 ovo mexido + café',
      '2 fatias pão integral + 15g requeijão light + café',
    ],
    'Jantar': [
      'Arroz (100g) + Feijão (60g) + Proteína (140g) + Vegetais',
      'Batata Doce (100g) + Proteína (140g) + Vegetais',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    final userSnap = await _db.userProfileStream.first;
    if (userSnap.exists) {
      final data = userSnap.data() as Map<String, dynamic>;
      final Map<String, dynamic>? saved = data['menu'];
      if (saved != null) {
        setState(() {
          saved.forEach((key, value) {
            if (_controllers.containsKey(key)) {
              _controllers[key]!.text = value.toString();
            }
          });
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _importPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) {
        setState(() => _isLoading = true);
        final bytes = File(result.files.single.path!).readAsBytesSync();
        final document = PdfDocument(inputBytes: bytes);
        String text = PdfTextExtractor(document).extractText();
        document.dispose();
        _smartParseMenu(text);
        setState(() { _isLoading = false; _isEditing = true; });
      }
    } catch (e) { setState(() => _isLoading = false); }
  }

  void _smartParseMenu(String rawText) {
    final text = rawText.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    setState(() {
      for (var meal in _mealOrder) {
        final pattern = RegExp('$meal' + r'[:\-]*\s*(.*?)(?=' + _mealOrder.join('|') + r'|OBS:|$)', caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null) {
          _controllers[meal]!.text = match.group(1)!.trim();
        }
      }
    });
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, String> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    await _db.saveMenu(data);
    setState(() { _isEditing = false; _isLoading = false; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cardápio atualizado!'), backgroundColor: Colors.green));
  }

  // --- ALTERADO: DIÁLOGO NO MEIO DA TELA E CORREÇÃO DE OVERFLOW ---
  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView( // Evita overflow vertical em telas pequenas
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            title: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded( // CORREÇÃO DE OVERFLOW NO TÍTULO
                  child: Text(
                    'MAIS CONSUMIDOS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 22),
                  onPressed: () async {
                    await _db.clearMenuStats();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.topMenuOptions,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Text("Nenhum dado coletado da Home ainda.");

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.blue.shade50,
                          child: Text("${data['count']}x", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(data['option'], style: const TextStyle(fontSize: 13)),
                        subtitle: Text(data['mealType'], style: const TextStyle(fontSize: 10)),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("FECHAR")),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0, pinned: true, backgroundColor: primaryGreen,
            actions: [
              IconButton(icon: const Icon(Icons.analytics_outlined), onPressed: _showStatsDialog),
              IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _importPDF),
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.white),
                onPressed: () => _isEditing ? _saveData() : setState(() => _isEditing = true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Meu Cardápio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryGreen, Color(0xFF4CAF50)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ..._mealOrder.map((meal) => _buildMealCard(meal, primaryGreen)),
                  _buildMenuCard('Observações', primaryGreen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String title, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: themeColor.withOpacity(0.7), size: 20),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF374151))),
              ],
            ),
            const SizedBox(height: 15),
            if (_isEditing)
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(filled: true, fillColor: Colors.blue.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), labelText: 'Modelo Sugerido'),
                    items: (_mealOptions[title] ?? []).map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (val) { if (val != null) setState(() => _controllers[title]!.text = val); },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controllers[title],
                    maxLines: null,
                    decoration: InputDecoration(filled: true, fillColor: Colors.blue.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), hintText: "Personalize aqui..."),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _controllers[title]!.text.isEmpty ? "Nenhum plano definido." : _controllers[title]!.text,
                    style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                  const Divider(height: 30),
                  const Text('OPÇÕES DO PLANO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  ...(_mealOptions[title] ?? []).map((opt) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(opt, style: const TextStyle(fontSize: 13, color: Colors.black54))),
                      ],
                    ),
                  )).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(String key, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.note_alt_outlined, color: themeColor, size: 20), const SizedBox(width: 10), Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))]),
            const SizedBox(height: 12),
            _isEditing
                ? TextField(controller: _controllers[key], maxLines: null, decoration: InputDecoration(filled: true, fillColor: Colors.blue.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))
                : Text(_controllers[key]!.text.isEmpty ? 'Nenhuma informação cadastrada.' : _controllers[key]!.text, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}