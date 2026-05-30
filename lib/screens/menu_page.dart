import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class MealEntry {
  TextEditingController titleController;
  List<TextEditingController> optionsControllers;

  MealEntry({required String title, required List<String> options})
      : titleController = TextEditingController(text: title),
        optionsControllers = options.isEmpty
            ? [TextEditingController()]
            : options.map((o) => TextEditingController(text: o)).toList();

  void dispose() {
    titleController.dispose();
    for (var c in optionsControllers) {
      c.dispose();
    }
  }
}

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

  List<MealEntry> _mealEntries = [];
  MealEntry? _obsEntry;

  final List<String> sugestoesNomes = [
    'Café da Manhã', 'Almoço', 'Jantar', 'Lanche Manhã',
    'Lanche Tarde', 'Lanche Noite', 'Pré Treino', 'Pós Treino',
    'Suplemento', 'Ceia'
  ];

  void _addNewMeal() {
    final TextEditingController nomeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Adicionar Refeição",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                autofocus: true, // Abre o teclado automaticamente
                decoration: const InputDecoration(
                  hintText: "Nome da refeição",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 15),
              const Text("Sugestões",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: sugestoesNomes.map((nome) {
                  return ActionChip(
                    label: Text(nome, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      nomeController.text = nome;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              if (nomeController.text.isNotEmpty) {
                setState(() {
                  _mealEntries.add(MealEntry(title: nomeController.text, options: [""]));
                  _isEditing = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("ADICIONAR"),
          ),
        ],
      ),
    );
  }

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
    for (var entry in _mealEntries) { entry.dispose(); }
    _obsEntry?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  String _formatExtractedText(String text) {
    if (text.isEmpty) return text;
    String formatted = text;
    formatted = formatted.replaceAll(RegExp(r'(?i)Opç[ãa]o\s*(\d+)'), '\n• Opção \$1');
    formatted = formatted.replaceAll(RegExp(r'(?i)OBS:'), '\n\n📌 OBS:');
    formatted = formatted.replaceAll(RegExp(r' +'), ' ').trim();
    if (formatted.startsWith('\n')) {
      formatted = formatted.replaceFirst(RegExp(r'\n+'), '');
    }
    return formatted;
  }

  // --- CARREGAMENTO (AJUSTADO PARA RESPEITAR A ORDEM SALVA) ---
  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    final userSnap = await _db.userProfileStream.first;

    if (userSnap.exists) {
      final data = userSnap.data() as Map<String, dynamic>;
      final Map<String, dynamic>? savedMenu = data['menu'];
      final List<dynamic>? savedSchedules = data['meal_schedules'];

      if (savedMenu != null && savedMenu.isNotEmpty) {
        List<MealEntry> loadedEntries = [];

        // 1. Prioridade: Carregar na ordem da lista 'meal_schedules'
        if (savedSchedules != null && savedSchedules.isNotEmpty) {
          for (var schedule in savedSchedules) {
            String name = schedule['name'];
            if (savedMenu.containsKey(name)) {
              loadedEntries.add(MealEntry(title: name, options: _parseValueToList(savedMenu[name])));
            }
          }
          // 2. Segurança: Adiciona itens do menu que talvez não estejam no schedule
          savedMenu.forEach((key, value) {
            if (key != 'Observações' && !loadedEntries.any((e) => e.titleController.text == key)) {
              loadedEntries.add(MealEntry(title: key, options: _parseValueToList(value)));
            }
          });
        } else {
          // 3. Fallback: Ordem alfabética ou padrão caso nunca tenha salvo a ordem
          savedMenu.forEach((key, value) {
            if (key != 'Observações') {
              loadedEntries.add(MealEntry(title: key, options: _parseValueToList(value)));
            }
          });
          loadedEntries.sort((a, b) {
            int indexA = sugestoesNomes.indexOf(a.titleController.text);
            int indexB = sugestoesNomes.indexOf(b.titleController.text);
            return (indexA == -1 ? 99 : indexA).compareTo(indexB == -1 ? 99 : indexB);
          });
        }

        _mealEntries = loadedEntries;
        if (savedMenu.containsKey('Observações')) {
          _obsEntry = MealEntry(title: 'Observações', options: _parseValueToList(savedMenu['Observações']));
        }
      } else {
        _mealEntries = sugestoesNomes.map((m) => MealEntry(title: m, options: [""])).toList();      }
    }
    _obsEntry ??= MealEntry(title: 'Observações', options: [""]);
    setState(() => _isLoading = false);
  }

  List<String> _parseValueToList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.contains('•')) {
      return value.split('•').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [value.toString()];
  }

  // --- SALVAMENTO (SINCRONIZA ORDEM E HORÁRIOS) ---
  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Map<String, String> menuData = {};
    List<Map<String, dynamic>> updatedSchedules = [];

    // Pegamos horários atuais para preservar horas/minutos originais
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    List<dynamic> existingSchedules = userDoc.data()?['meal_schedules'] ?? [];

    // Iteramos na ordem ATUAL da tela (_mealEntries)
    for (int i = 0; i < _mealEntries.length; i++) {
      var entry = _mealEntries[i];
      String title = entry.titleController.text.trim();

      if (title.isNotEmpty) {
        menuData[title] = entry.optionsControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .join(' • ');

        // Tenta encontrar o horário antigo para este item pelo nome
        var oldMatch = existingSchedules.firstWhere(
                (s) => s['name'] == title,
            orElse: () => (existingSchedules.length > i) ? existingSchedules[i] : null
        );

        updatedSchedules.add({
          'id': i + 1,
          'name': title,
          'hour': oldMatch != null ? oldMatch['hour'] : (7 + i),
          'minute': oldMatch != null ? oldMatch['minute'] : 0,
        });
      }
    }

    if (_obsEntry != null) {
      menuData['Observações'] = _obsEntry!.optionsControllers[0].text;
    }

    try {
      // SALVAMENTO UNIFICADO NO FIRESTORE
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'menu': menuData,
        'meal_schedules': updatedSchedules,
      });

      // Atualiza os alarmes do celular com os novos nomes/horários
      await NotificationService().scheduleCustomNotifications(updatedSchedules);

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cardápio e Sugestões sincronizados! 🔄'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Erro ao sincronizar cardápio: $e");
    }
  }

  void _deleteMeal(int index) {
    setState(() {
      _mealEntries[index].dispose();
      _mealEntries.removeAt(index);
      _isEditing = true; // Força salvar para atualizar a lista no banco
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0, pinned: true, backgroundColor: primaryGreen,
            leading: const BackButton(color: Colors.white),
            actions: [
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
              background: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryGreen, Color(0xFF4CAF50)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _mealEntries.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _mealEntries.removeAt(oldIndex);
                        _mealEntries.insert(newIndex, item);
                        _isEditing = true;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildMealCard(_mealEntries[index], index, primaryGreen, key: ValueKey(_mealEntries[index]));
                    },
                  ),
                  if (_obsEntry != null) _buildMenuCard(_obsEntry!, primaryGreen),
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
        tooltip: 'Adicionar nova refeição',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMealCard(MealEntry entry, int index, Color themeColor, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  if (_isEditing) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.reorder, color: Colors.grey, size: 20)),
                  Icon(Icons.restaurant_menu, color: themeColor.withOpacity(0.7), size: 20),
                  const SizedBox(width: 10),
                  _isEditing
                      ? SizedBox(width: 150, child: TextField(controller: entry.titleController, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), decoration: const InputDecoration(hintText: "Título", border: InputBorder.none, isDense: true)))
                      : Text(entry.titleController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF374151))),
                ]),
                if (_isEditing) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteMeal(index)),
              ],
            ),
            const SizedBox(height: 15),
            ...List.generate(entry.optionsControllers.length, (optIdx) => _buildOptionSubCard(entry, optIdx)),
            if (_isEditing) TextButton.icon(onPressed: () => setState(() => entry.optionsControllers.add(TextEditingController())), icon: const Icon(Icons.add, size: 16), label: const Text("ADICIONAR OPÇÃO"), style: TextButton.styleFrom(foregroundColor: themeColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSubCard(MealEntry entry, int optIdx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Row(
        children: [
          Text("Opção ${optIdx + 1}: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
          Expanded(child: TextField(controller: entry.optionsControllers[optIdx], enabled: _isEditing, maxLines: null, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, hintText: "Descreva a opção..."))),
          if (_isEditing && entry.optionsControllers.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red), onPressed: () => setState(() => entry.optionsControllers.removeAt(optIdx))),
        ],
      ),
    );
  }

  Widget _buildMenuCard(MealEntry entry, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.note_alt_outlined, color: themeColor, size: 20), const SizedBox(width: 10), Text(entry.titleController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))]),
            const SizedBox(height: 12),
            TextField(controller: entry.optionsControllers[0], enabled: _isEditing, maxLines: null, decoration: InputDecoration(filled: true, fillColor: Colors.blue.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
          ],
        ),
      ),
    );
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
        setState(() { _isLoading = false; _isEditing = true; });
      }
    } catch (e) { setState(() => _isLoading = false); }
  }

  void _smartParseMenu(String rawText) {
    final text = rawText.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    final titles = _mealEntries.map((e) => e.titleController.text).toList();
    setState(() {
      for (var entry in _mealEntries) {
        final pattern = RegExp('${RegExp.escape(entry.titleController.text)}' + r'[:\-]*\s*(.*?)(?=' + titles.join('|') + r'|OBS:|Dra\.|$)', caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null) {
          String content = _formatExtractedText(match.group(1)!.trim());
          entry.optionsControllers = [TextEditingController(text: content)];
        }
      }
    });
  }
}
