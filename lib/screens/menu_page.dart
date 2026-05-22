import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _showTitle = true;

  final Map<String, TextEditingController> _controllers = {};

  final List<String> _defaultMealOrder = [
    'Café da Manhã',
    'Lanche da Manhã',
    'Almoço',
    'Lanche da Tarde 1',
    'Lanche da Tarde 2',
    'Jantar'
  ];

  @override
  void initState() {
    super.initState();
    _loadMenuData();
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

  // --- FUNÇÃO DE FORMATAÇÃO PARA ORGANIZAR O TEXTO ---
  String _formatExtractedText(String text) {
    if (text.isEmpty) return text;

    String formatted = text;

    // 1. Adiciona quebra de linha e bullet point antes de "Opção" ou "Opcao"
    // CORREÇÃO: Escapado o $ com \ para não dar erro de identificador
    formatted = formatted.replaceAll(RegExp(r'(?i)Opç[ãa]o\s*(\d+)'), '\n• Opção \$1');

    // 2. Adiciona quebra de linha antes de observações
    formatted = formatted.replaceAll(RegExp(r'(?i)OBS:'), '\n\n📌 OBS:');

    // 3. Corrige espaços duplos e limpa o início/fim
    formatted = formatted.replaceAll(RegExp(r' +'), ' ').trim();

    // 4. Se o texto começar com quebras, remove-as
    if (formatted.startsWith('\n')) {
      formatted = formatted.replaceFirst(RegExp(r'\n+'), '');
    }

    return formatted;
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    final userSnap = await _db.userProfileStream.first;
    if (userSnap.exists) {
      final data = userSnap.data() as Map<String, dynamic>;
      final Map<String, dynamic>? saved = data['menu'];
      if (saved != null) {
        saved.forEach((key, value) {
          if (!_controllers.containsKey(key)) {
            _controllers[key] = TextEditingController();
          }
          _controllers[key]!.text = value.toString();
        });
      }
    }
    // Garante controladores para itens padrão
    for (var meal in _defaultMealOrder) {
      if (!_controllers.containsKey(meal)) _controllers[meal] = TextEditingController();
    }
    if (!_controllers.containsKey('Observações')) {
      _controllers['Observações'] = TextEditingController();
    }
    setState(() => _isLoading = false);
  }

  void _addNewMeal() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nova Refeição"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Nome (Ex: Ceia)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _controllers[nameController.text] = TextEditingController();
                  _isEditing = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("CRIAR"),
          )
        ],
      ),
    );
  }

  void _deleteMeal(String mealName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'menu.$mealName': FieldValue.delete(),
    });
    setState(() {
      _controllers[mealName]?.dispose();
      _controllers.remove(mealName);
    });
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, String> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    await _db.saveMenu(data);
    setState(() { _isEditing = false; _isLoading = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cardápio atualizado!'), backgroundColor: Colors.green)
      );
    }
  }

  Future<void> _importFile() async {
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

        _smartParseMenu(extractedText);
        setState(() {
          _isLoading = false;
          _isEditing = true;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Erro na importação: $e");
    }
  }

  void _smartParseMenu(String rawText) {
    final text = rawText.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    final allPossibleMeals = [..._defaultMealOrder, ..._controllers.keys].toSet().toList();

    setState(() {
      for (var meal in allPossibleMeals) {
        final pattern = RegExp(
            '$meal' + r'[:\-]*\s*(.*?)(?=' + allPossibleMeals.join('|') + r'|OBS:|Dra\.|$)',
            caseSensitive: false
        );
        final match = pattern.firstMatch(text);
        if (match != null) {
          String content = match.group(1)!.trim();
          content = _formatExtractedText(content);

          if (!_controllers.containsKey(meal)) _controllers[meal] = TextEditingController();
          _controllers[meal]!.text = content;
        }
      }
    });
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text('MAIS CONSUMIDOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.topMenuOptions,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Text("Sem dados.");
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(child: Text("${data['count']}x", style: const TextStyle(fontSize: 10))),
                    title: Text(data['option'], style: const TextStyle(fontSize: 13)),
                    subtitle: Text(data['mealType'], style: const TextStyle(fontSize: 10)),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("FECHAR"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);

    final sortedKeys = _controllers.keys.where((k) => k != 'Observações').toList()
      ..sort((a, b) {
        int indexA = _defaultMealOrder.indexOf(a);
        int indexB = _defaultMealOrder.indexOf(b);
        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;
        return indexA.compareTo(indexB);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0, pinned: true, backgroundColor: primaryGreen,
            leading: const BackButton(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.analytics_outlined), onPressed: _showStatsDialog),
              IconButton(icon: const Icon(Icons.file_present), onPressed: _importFile),
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.white),
                onPressed: () => _isEditing ? _saveData() : setState(() => _isEditing = true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showTitle ? 1.0 : 0.0,
                child: const Text('Meu Cardápio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              background: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [primaryGreen, Color(0xFF4CAF50)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter
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
                  ...sortedKeys.map((meal) => _buildMealCard(meal, primaryGreen)),
                  if (_controllers.containsKey('Observações')) _buildMenuCard('Observações', primaryGreen),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        onPressed: _addNewMeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMealCard(String title, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: themeColor.withOpacity(0.7), size: 20),
                    const SizedBox(width: 10),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF374151))),
                  ],
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteMeal(title),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            _isEditing
                ? TextField(
              controller: _controllers[title],
              maxLines: null,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.blue.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                hintText: "Personalize aqui...",
              ),
            )
                : Text(
              _controllers[title]!.text.isEmpty ? "Nenhum plano definido." : _controllers[title]!.text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(String key, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.note_alt_outlined, color: themeColor, size: 20),
              const SizedBox(width: 10),
              Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))
            ]),
            const SizedBox(height: 12),
            _isEditing
                ? TextField(
                controller: _controllers[key],
                maxLines: null,
                decoration: InputDecoration(
                    filled: true, fillColor: Colors.blue.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                )
            )
                : Text(
                _controllers[key]!.text.isEmpty ? 'Nenhuma informação.' : _controllers[key]!.text,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black54)
            ),
          ],
        ),
      ),
    );
  }
}