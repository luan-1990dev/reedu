import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class SupplementationPage extends StatefulWidget {
  const SupplementationPage({super.key});

  @override
  State<SupplementationPage> createState() => _SupplementationPageState();
}

class _SupplementationPageState extends State<SupplementationPage> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;
  bool _isEditing = false;

  List<TextEditingController> _nameControllers = [];
  List<TextEditingController> _valueControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeDefaultControllers();
    _loadData();
  }

  void _initializeDefaultControllers() {
    final defaults = [
      ['Vitamina D', '2000UI'], ['Vitamina K2', '90mcg'], ['Vitamina C', '90mg'],
      ['Zinco quelado', '6mg'], ['Magnésio Quelado', '300mg'], ['Cianocobalamina', '500mcg'],
      ['Nitrato de tiamina', '100mg'], ['Cloridato de piridoxina', '100mg'],
      ['Picolinato de cromo', '300mcg'], ['Maca peruana', '500mg'], ['Tribullus Terrestris', '500mg'],
    ];

    for (var item in defaults) {
      _nameControllers.add(TextEditingController(text: item[0]));
      _valueControllers.add(TextEditingController(text: item[1]));
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('supplements')) {
        final Map<String, dynamic> saved = doc.data()!['supplements'];
        if (saved.isNotEmpty) {
          setState(() {
            _nameControllers.clear();
            _valueControllers.clear();
            saved.forEach((key, value) {
              _nameControllers.add(TextEditingController(text: key));
              _valueControllers.add(TextEditingController(text: value.toString()));
            });
          });
        }
      }
    }
  }

  @override
  void dispose() {
    for (var c in _nameControllers) { c.dispose(); }
    for (var c in _valueControllers) { c.dispose(); }
    super.dispose();
  }

  void _addNewRow() {
    setState(() {
      _nameControllers.add(TextEditingController());
      _valueControllers.add(TextEditingController());
      _isEditing = true;
    });
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
        _parseSupplements(text);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Suplementos importados! Verifique e salve.'),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _isEditing = true;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseSupplements(String text) {
    setState(() {
      for (int i = 0; i < _nameControllers.length; i++) {
        final key = _nameControllers[i].text;
        if (key.isEmpty) continue;
        final regExp = RegExp('$key[\\.\\s]+([\\d\\w]+)', caseSensitive: false);
        final match = regExp.firstMatch(text);
        if (match != null) {
          _valueControllers[i].text = match.group(1)!;
        }
      }
    });
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, String> data = {};

    for (int i = 0; i < _nameControllers.length; i++) {
      if (_nameControllers[i].text.isNotEmpty) {
        data[_nameControllers[i].text] = _valueControllers[i].text;
      }
    }
    try {
      await _db.saveSupplements(data);
      if (mounted) {
        setState(() { _isEditing = false; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Suplementação salva com sucesso!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6A1B9A);
    const Color bgSoft = Color(0xFFF3E5F5);

    return Scaffold(
      backgroundColor: bgSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0, pinned: true, backgroundColor: primaryPurple, elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _importPDF),
              if (!_isEditing) IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => setState(() => _isEditing = true))
              else IconButton(icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check, color: Colors.white, size: 30), onPressed: _isLoading ? null : _saveData),
            ],
            flexibleSpace: const FlexibleSpaceBar(
              centerTitle: true,
              title: Text('Suplementação', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _db.todayStats,
            builder: (context, snapshot) {
              final stats = snapshot.data?.data() as Map<String, dynamic>?;
              final mealChecks = stats?['meal_checks'] ?? {};
              final bool isTaken = mealChecks['suplementos'] == true;

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                        child: CheckboxListTile(
                          title: const Text('Tomei meus suplementos hoje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: isTaken,
                          activeColor: primaryPurple,
                          onChanged: (val) => _db.toggleMealCompletion('suplementos', val ?? false),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(children: [Icon(Icons.medication, color: primaryPurple), SizedBox(width: 10), Text('FÓRMULA MANIPULADA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _nameControllers.length,
                              itemBuilder: (context, index) => _buildSupplementRow(index, primaryPurple),
                            ),
                            if (_isEditing)
                              TextButton.icon(
                                onPressed: _addNewRow,
                                icon: const Icon(Icons.add, color: primaryPurple),
                                label: const Text('ADICIONAR ITEM', style: TextStyle(color: primaryPurple)),
                              ),
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Posologia: Tomar 1 dose ao dia após o café.', style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildBrandSection(),
                      const SizedBox(height: 20),
                      _buildBeerSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupplementRow(int index, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _isEditing
                ? TextField(
              controller: _nameControllers[index],
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: const InputDecoration(isDense: true, hintText: 'Nome', border: UnderlineInputBorder()),
            )
                : Text(_nameControllers[index].text, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _isEditing
                ? TextField(
              controller: _valueControllers[index],
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
              decoration: const InputDecoration(isDense: true, hintText: 'Dose', border: UnderlineInputBorder()),
            )
                : Text(_valueControllers[index].text, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
              onPressed: () => setState(() {
                _nameControllers.removeAt(index);
                _valueControllers.removeAt(index);
              }),
            )
        ],
      ),
    );
  }

  Widget _buildBrandSection() {
    final brands = ['PROBIÓTICA', 'INTEGRALMÉDICA', 'MAX TITANIUM', 'GROWTH', 'ESSENTIAL NUTRITION'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SUGESTÕES DE MARCAS DE WHEY PROTEIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brands.map((b) => Chip(label: Text(b, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.purple.shade50, side: BorderSide.none)).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildBeerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(25)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.sports_bar, color: Colors.white), SizedBox(width: 10), Text('CERVEJAS LIGHT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
          SizedBox(height: 10),
          Text('Michelob Ultra, Amstel Ultra, Heineken, Corona Zero, Stella Pure Gold', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}