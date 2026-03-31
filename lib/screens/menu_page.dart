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

  final List<String> _breakfastOptions = [
    'Opção 1: 1 pão francês s/ miolo + 3 ovos mexidos + café + fruta',
    'Opção 2: 2 fatias pão integral + 3 ovos mexidos + café + fruta',
    'Opção 3: 1 pão francês s/ miolo + 70g frango desfiado + café + fruta',
    'Opção 4: 1 crepioca (30g goma + 3 ovos) + 15g requeijão light + café + fruta',
  ];

  final List<String> _morningSnackOptions = [
    'Opção 1: 30g de whey protein isolado + 200ml de água + 1 banana nanica',
    'Opção 2: 1 pote de iogurte natural integral (170g) + 1 banana nanica',
  ];

  final List<String> _lunchOptions = [
    'Opção 1: Arroz (120g) + Feijão (90g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
    'Opção 2: Macarrão Integral (120g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
    'Opção 3: Batata Doce (120g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
    'Opção 4: Mandioca (120g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
  ];

  final List<String> _afternoonSnack1Options = [
    'Opção 1: 1 porção de fruta (maçã, pêra ou goiaba)',
  ];

  final List<String> _afternoonSnack2Options = [
    'Opção 1: 1 pão francês s/ miolo + 1 ovo mexido + café',
    'Opção 2: 2 fatias pão integral + 1 ovo mexido + café',
    'Opção 3: 2 fatias pão integral + 15g requeijão light + café',
    'Opção 4: 1 pão francês s/ miolo + 30g patê frango/atum + café',
    'Opção 5: 2 fatias pão integral + 10g pasta amendoim + café',
  ];

  final List<String> _dinnerOptions = [
    'Opção 1: Arroz (100g) + Feijão (60g) + Proteína (140g) + Vegetais A e B + Sobremesa',
    'Opção 2: Batata Doce (100g) + Proteína (140g) + Vegetais A e B + Sobremesa',
  ];

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('menu')) {
        final Map<String, dynamic> saved = doc.data()!['menu'];
        setState(() {
          saved.forEach((key, value) {
            if (_controllers.containsKey(key)) {
              _controllers[key]!.text = value.toString();
            }
          });
        });
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _importPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
        String text = PdfTextExtractor(document).extractText();
        document.dispose();
        _parseMenu(text);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cardápio importado! Verifique e salve.')));
          _isEditing = true;
        }
      }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ler PDF: $e'))); }
    }
  }

  void _parseMenu(String text) {
    _controllers.forEach((key, controller) {
      final regExp = RegExp(key + r'[\s:]+([\s\S]+?)(?=\n[A-Z][a-z]+ da|\nAlmoço|\nJantar|\nObservações|$)');
      final match = regExp.firstMatch(text);
      if (match != null) { setState(() => controller.text = match.group(1)!.trim()); }
    });
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, String> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    try {
      await _db.saveMenu(data);
      if (mounted) { setState(() { _isEditing = false; _isLoading = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cardápio salvo com sucesso!'))); }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'))); }
    }
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Text('MAIS CONSUMIDOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1967D2))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 22),
                      onPressed: () async {
                        await _db.clearMenuStats();
                        if (context.mounted) Navigator.pop(context);
                      },
                      tooltip: 'Limpar tudo',
                    ),
                  ],
                ),
                const Divider(height: 30),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.topMenuOptions,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Nenhum dado registrado.", textAlign: TextAlign.center)));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${data['mealType']}: ${snapshot.data!.docs[index].id.split(':')[0]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              const SizedBox(width: 8),
                              Text('${data['count']}x', style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);
    const Color bgSoft = Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: bgSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150.0, pinned: true, backgroundColor: primaryGreen, elevation: 0,
            leadingWidth: 100,
            leading: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                IconButton(icon: const Icon(Icons.analytics_outlined, color: Colors.white), onPressed: _showStatsDialog, tooltip: 'Estatísticas'),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _importPDF, tooltip: 'Importar PDF'),
              if (!_isEditing) IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => setState(() => _isEditing = true))
              else IconButton(icon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, color: Colors.white, size: 30), onPressed: _isLoading ? null : _saveData),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Meu Cardápio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryGreen, Color(0xFF4CAF50)]))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDropdownSection('Café da Manhã', _breakfastOptions, Icons.wb_sunny_outlined, primaryGreen),
                  _buildDropdownSection('Lanche da Manhã', _morningSnackOptions, Icons.wb_twilight, primaryGreen),
                  _buildDropdownSection('Almoço', _lunchOptions, Icons.restaurant, primaryGreen),
                  _buildDropdownSection('Lanche da Tarde 1', _afternoonSnack1Options, Icons.apple, primaryGreen),
                  _buildDropdownSection('Lanche da Tarde 2', _afternoonSnack2Options, Icons.coffee, primaryGreen),
                  _buildDropdownSection('Jantar', _dinnerOptions, Icons.nightlight_round, primaryGreen),
                  _buildMenuCard('Observações', primaryGreen), // Campo Observações adicionado
                  ..._controllers.keys.where((k) => k != 'Café da Manhã' && k != 'Lanche da Manhã' && k != 'Almoço' && k != 'Lanche da Tarde 1' && k != 'Lanche da Tarde 2' && k != 'Jantar' && k != 'Observações').map((key) => _buildMenuCard(key, primaryGreen)).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSection(String key, List<String> options, IconData icon, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: themeColor, size: 20)),
                const SizedBox(width: 12),
                Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ],
            ),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true, decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), labelText: 'Escolha uma opção'),
                    items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (val) { if (val != null) setState(() => _controllers[key]!.text = val); },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _controllers[key], maxLines: null, decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), labelText: 'Texto personalizado')),
                  const SizedBox(height: 16),
                ],
              ),
            )
          else
            Column(
              children: options.map((opt) {
                return CheckboxListTile(
                  title: Text(opt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  value: false, activeColor: themeColor, contentPadding: const EdgeInsets.symmetric(horizontal: 16), controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (val) async {
                    if (val == true) {
                      await _db.logMenuOptionConsumption(key, opt);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Consumo de "${opt.split(':')[0]}" registrado!')));
                    }
                  },
                );
              }).toList(),
            ),
          if (key == 'Café da Manhã')
            Padding(padding: const EdgeInsets.all(16.0), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_outline, color: Colors.redAccent, size: 18), SizedBox(width: 8), Expanded(child: Text('OBS: Tomar 6g de creatina após o café.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)))]))),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String key, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(key == 'Observações' ? Icons.note_alt_outlined : Icons.restaurant_menu, color: themeColor, size: 20),
                const SizedBox(width: 10),
                Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ],
            ),
            const SizedBox(height: 12),
            _isEditing
                ? TextField(
                    controller: _controllers[key],
                    maxLines: null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  )
                : Text(
                    _controllers[key]!.text.isEmpty ? 'Nenhuma informação cadastrada.' : _controllers[key]!.text,
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black54),
                  ),
          ],
        ),
      ),
    );
  }
}
