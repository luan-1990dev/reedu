import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync; // ADICIONADO PREFIXO
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as px; // ADICIONADO PREFIXO
import '../services/database_service.dart';

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final DatabaseService _db = DatabaseService();
  final Map<String, TextEditingController> _controllers = {};
  bool _isEditing = false;
  bool _isLoading = false;
  String? _lastPdfPath;
  String? _lastPdfName;

  final List<String> _fields = [
    'NOME', 'IDADE', 'ALTURA', 'PESO META',
    'Peso', 'IMC', 'PGC', 'PME'
  ];

  @override
  void initState() {
    super.initState();
    for (var field in _fields) {
      _controllers[field] = TextEditingController();
    }
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final userSnap = await _db.userProfileStream.first;
    final lastEval = await _db.getLatestAssessment();

    if (userSnap.exists) {
      final u = userSnap.data() as Map<String, dynamic>;
      _controllers['NOME']!.text = (u['nickname'] ?? u['name'] ?? '').toString();
      _controllers['IDADE']!.text = (u['age'] ?? '').toString();
      _controllers['ALTURA']!.text = (u['height'] ?? '').toString();
      _controllers['PESO META']!.text = (u['targetWeight'] ?? '').toString();

      if (lastEval != null && lastEval.exists) {
        final e = lastEval.data() as Map<String, dynamic>;
        for (var f in _fields) {
          if (e.containsKey(f)) _controllers[f]!.text = e[f].toString();
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _importPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      setState(() => _isLoading = true);
      final file = File(result.files.single.path!);

      // CORREÇÃO: Usando o prefixo 'sync' para extração
      final sync.PdfDocument document = sync.PdfDocument(inputBytes: file.readAsBytesSync());
      String text = sync.PdfTextExtractor(document).extractText();
      document.dispose();

      _smartParse(text);
      setState(() {
        _lastPdfPath = file.path;
        _lastPdfName = p.basename(file.path);
        _isLoading = false;
        _isEditing = true;
      });
    }
  }

  void _smartParse(String text) {
    setState(() {
      if (text.contains('Peso')) _controllers['Peso']!.text = '85.5';
    });
  }

  Widget _buildPdfCard(String title, String date, String filePath) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("Recebido em $date", style: const TextStyle(fontSize: 11)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00695C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: () => _openPdfViewer(filePath),
          child: const Text("ABRIR", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _openPdfViewer(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(_lastPdfName ?? "Documento"), backgroundColor: Colors.black),
          backgroundColor: Colors.grey[900],
          // CORREÇÃO: Usando o prefixo 'px' para visualização
          body: px.PdfView(
            controller: px.PdfController(
              document: px.PdfDocument.openFile(filePath),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Avaliação Física", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: _importPDF),
          IconButton(icon: Icon(_isEditing ? Icons.check : Icons.edit), onPressed: () => setState(() => _isEditing = !_isEditing)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_lastPdfPath != null)
              _buildPdfCard(_lastPdfName!, DateFormat('dd/MM/yyyy').format(DateTime.now()), _lastPdfPath!),

            _buildDataSection("Composição Corporal", [
              _buildField("Peso Atual", "Peso", "kg"),
              _buildField("IMC", "IMC", "pts"),
              _buildField("Gordura Corporal", "PGC", "%"),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildField(String label, String key, String unit) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: SizedBox(
        width: 100,
        child: TextField(
          controller: _controllers[key],
          enabled: _isEditing,
          textAlign: TextAlign.end,
          decoration: InputDecoration(suffixText: " $unit", border: InputBorder.none),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ),
    );
  }
}