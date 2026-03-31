import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
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

  final Map<String, TextEditingController> _controllers = {
    'Vitamina D': TextEditingController(text: '2000UI'),
    'Vitamina K2': TextEditingController(text: '90mcg'),
    'Vitamina C': TextEditingController(text: '90mg'),
    'Zinco quelado': TextEditingController(text: '6mg'),
    'Magnésio Quelado': TextEditingController(text: '300mg'),
    'Cianocobalamina': TextEditingController(text: '500mcg'),
    'Nitrato de tiamina': TextEditingController(text: '100mg'),
    'Cloridato de piridoxina': TextEditingController(text: '100mg'),
    'Picolinato de cromo': TextEditingController(text: '300mcg'),
    'Maca peruana': TextEditingController(text: '500mg'),
    'Tribullus Terrestris': TextEditingController(text: '500mg'),
  };

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

        _parseSupplements(text);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suplementos importados! Verifique e salve.')));
          _isEditing = true;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ler PDF: $e')));
      }
    }
  }

  void _parseSupplements(String text) {
    _controllers.forEach((key, controller) {
      final regExp = RegExp('$key[\\.\\s]+([\\d\\w]+)');
      final match = regExp.firstMatch(text);
      if (match != null) {
        setState(() => controller.text = match.group(1)!);
      }
    });
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, String> data = {};
    _controllers.forEach((key, controller) => data[key] = controller.text);
    try {
      await _db.saveSupplements(data);
      if (mounted) {
        setState(() { _isEditing = false; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suplementação salva com sucesso!')));
      }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'))); }
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
            expandedHeight: 150.0,
            pinned: true,
            backgroundColor: primaryPurple,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _importPDF, tooltip: 'Importar PDF'),
              if (!_isEditing) IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => setState(() => _isEditing = true))
              else IconButton(icon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, color: Colors.white, size: 30), onPressed: _isLoading ? null : _saveData),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Suplementação', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryPurple, Color(0xFFAB47BC)]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(children: [Icon(Icons.medication, color: primaryPurple), SizedBox(width: 10), Text('FÓRMULA MANIPULADA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
                        ),
                        ..._controllers.keys.map((key) => _buildSupplementRow(key, primaryPurple)).toList(),
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Posologia: Tomar 1 dose ao dia após o café.', style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple, fontSize: 13)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSupplementRow(String key, Color primaryPurple) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          _isEditing 
            ? SizedBox(width: 80, child: TextField(controller: _controllers[key], textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple), decoration: const InputDecoration(isDense: true)))
            : Text(_controllers[key]!.text, style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple, fontSize: 15)),
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
          const Text('SUGESTÕES DE MARCAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
