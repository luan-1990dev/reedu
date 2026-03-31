import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';


class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isLoading = false;

  List<Map<String, dynamic>> _recipes = [
    {
      'id': '1',
      'title': 'PATÊ DE FRANGO',
      'ingredients': '3 colheres de sopa de frango desfiado e temperado\n½ cenoura ralada\n4 azeitonas picadas\n1 colher de sopa de cebola ralada\n1/2 pote de requeijão light\nTempero a gosto',
      'method': 'Misture o frango com os demais ingredientes. Coloque em um recipiente com tampa e guarde na geladeira.',
      'category': 'Salgado'
    },
    {
      'id': '2',
      'title': 'PATÊ DE ATUM',
      'ingredients': '1 lata de atum\n1 colher de sopa de cebolinha verde picado\n1 colher de sopa de salsinha picado\n1/2 pote de requeijão light\n1 pitada de sal (se preferir)',
      'method': 'Misture todos os ingredientes e guarde em um recipiente fechado na geladeira.',
      'category': 'Salgado'
    },
    {
      'id': '3',
      'title': 'RECEITA DE IOGURTE NATURAL',
      'ingredients': '1 litro de leite semidesnatado\n1 iogurte natural',
      'method': 'Ferva o leite, espere amornar, mas não deixe ficar frio. Misture o iogurte junto ao leite morno, e coloque num recipiente médio ou grande (o equivalente a 1 litro) e deixe descansar de 12 a 24 horas. De vez em quando mexa para ver como ficou a consistência. Você pode bater no liquidificador com morangos para dar sabor.',
      'category': 'Básico'
    },
    {
      'id': '4',
      'title': 'HAMBÚRGUER DE CARNE VERMELHA CASEIRO',
      'ingredients': '500 gramas de carne vermelha moída (patinho)\n1 ovo inteiro\nMeia cebola picada\n2 dentes de alho picados\nSal, pimenta e outros temperos naturais a gosto',
      'method': 'O preparo do hambúrguer não poderia ser mais simples. Misture todos os ingredientes em um pote até que a mistura fique homogênea. Molde os hambúrgueres usando a mão com 2 colheres de sopa da mistura. Use uma frigideira antiaderente. Agora, em fogo baixo, coloque os hambúrgueres um a um na frigideira e vire-os constantemente até ficarem no ponto desejado.',
      'category': 'Salgado'
    },
    {
      'id': '5',
      'title': 'HAMBÚRGUER DE FRANGO COM AVEIA',
      'ingredients': '500g de peito de frango desfiado (quanto mais desfiado melhor)\n1 ovo inteiro\n1 cebola ralada\n3 colheres de sopa de aveia em flocos finos\nSal e pimenta a gosto\nSalsa picada a gosto',
      'method': 'Reserve um pote e misture todos os ingredientes até que a mistura fique o mais homogênea possível. Em seguida, pegue a mistura e molde bolinhos com as mãos para formar cerca de seis hambúrgueres. Agora basta fritar em uma frigideira antiaderente ou usar um grill até ficar no ponto desejado.',
      'category': 'Salgado'
    },
    {
      'id': '6',
      'title': 'ALMÔNDEGAS COM AVEIA',
      'ingredients': '1 dente de alho amassado\n1 tomate sem pele e sem sementes picado\nSal e orégano a gosto\n1/2 cebola ralada\n1/2 xícara de chá de aveia em flocos\n300 g de carne moída',
      'method': 'Junte 300 g de carne moída, 1/2 cebola ralada, 1 dente de alho amassado, 1/2 xícara de chá de aveia em flocos, tomate e tempere com sal e pimenta do reino a gosto. Misture bem. Modele as almôndegas tomando porções 1/2 colher sopa. Coloque-as em uma assadeira untada, regue com azeite e deixe no forno até dourar. Retire as almôndegas e enfeite com folhas de alface. Você também pode cozinhá-las, coloque 1 lata de molho de tomate pronto em uma panela com 1/2 xícara de água. Cozinhe por aproximadamente 20 minutos com panela tampada e mexendo sempre, com cuidado para não desmanchar as bolinhas.',
      'category': 'Salgado'
    },
    {
      'id': '7',
      'title': 'STROGONOFF LIGHT DE FRANGO',
      'ingredients': '800 g de peito de frango em tiras;\n2 colheres de sopa de azeite;\n1 tomate grande picado;\n1 colher de chá de mostarda;\nSal a gosto;\n1 cebola média bem picada;\n1 xícara de chá de água quente;\n½ pote de requeijão light.',
      'method': 'Em uma frigideira refogue a cebola até ficar translúcida, então acrescente o frango e os pedaços de tomate. Tampe e deixe cozinhar. Adicione a mostarda, sal e água e misture. Deixe por mais alguns minutos com a tampa fechada até o frango amaciar. Adicione o requeijão até dar consitência. Sirva.',
      'category': 'Salgado'
    },
    {
      'id': '8',
      'title': 'STROGONOFF LIGHT COM ALCATRA',
      'ingredients': '400 g de alcatra;\n2 tomates;\n1 cebola média;\n3 colheres de sopa de iogurte natural desnatado;\nSal a gosto;\n3 colheres de sopa de requeijão light.',
      'method': 'Corte a cebola em cubinhos e refogue em uma frigideira com um pouco de azeite. Então acrescente o tomate picado à cebola e deixe soltar água. Corte a carne em fatias finas e leve para refogar na panela e tampe até que cozinhe. Quando estiverem douradas acrescente um pouco de água se for necessário para que não grudem na panela. Ao final, acrescente o requeijão light e depois as colheres de iogurte. Mexa tudo até incorporar, desligue e sirva acompanhado de batata doce rústica ou arroz integral.',
      'category': 'Salgado'
    },
    {
      'id': '9',
      'title': 'MOUSSE DE CHOCOLATE LIGHT',
      'ingredients': '40 g de chocolate meio amargo picado;\n1 colher de chá de gelatina em pó incolor;\n6 colheres de sopa de leite desnatado;\n2 colheres de chá de adoçante culinário;\n2 claras.',
      'method': 'Adicione o chocolate em uma vasilha com o leite e leve ao fogo médio em banho maria até derreter. Adicione a gelatina dissolvida no leite e deixe hidratar por 1 minuto. Junte a gelatina ao chocolate e mexa até que incorpore completamente. Retire do fogo e acrescente adoçante. Bata as claras em ponto de neve e depois adicione suavemente ao chocolate. Despeje em taças e leve na geladeira para ganhar consistência.',
      'category': 'Doce'
    },
    {
      'id': '10',
      'title': 'MOUSSE DE LIMÃO',
      'ingredients': '200 ml de leite de coco\n250 ml de leite em pó desnatado\nSuco de 1 limão\n2 colheres de sopa rasas de xilitol, açúcar demerara ou adoçante\nRaspas de limão para decorar',
      'method': 'Em um liquidificador, coloque todos os ingredientes e bata por cerca de 5 minutos; Em seguida, distribua o creme em vários recipientes e finalize com as raspas de limão por cima. Sim, essa mousse é rápida, prática e muito saborosa!',
      'category': 'Doce'
    },
    {
      'id': '11',
      'title': 'MOUSSE DE MARACUJÁ SEM AÇÚCAR',
      'ingredients': '1 xícara de leite em pó\n½ xícara de água morna\n2 potes de iogurte natural\n3 colheres de xilitol\nSuco de 2 maracujás\n\nCALDA:\nPolpa de 1 maracujá\n1 colher de sopa de xilitol',
      'method': 'MOUSSE: No liquidificador, bata o leite em pó e a água. Adicione o iogurte natural, o xilitol e o suco de maracujá. Despeje a mistura em uma taça.\n\nCALDA: Misture a polpa de maracujá e o xilitol. Leve ao fogo até engrossar. Despeje a calda sobre a mousse.',
      'category': 'Doce'
    },
    {
      'id': '12',
      'title': 'MOUSSE FIT DE MORANGO',
      'ingredients': '200g de morangos congelados\n100g de leite em pó desnatado\n150ml de água\n1 suco clight sabor morango\n250g de iogurte natural',
      'method': 'Coloque os morangos o leite em pó e a água no liquidificador e bata bem. Adicione o iogurte e deixe bater por 3 minutos. Por fim coloque o suco e deixe bater por mais 5 minutos. Coloque em um refratário e leve para geladeira por cerca de 4 horas.',
      'category': 'Doce'
    },
  ];

  Future<void> _importPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
        String text = PdfTextExtractor(document).extractText();
        document.dispose();

        _parseNewRecipes(text);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Novas receitas identificadas e adicionadas!')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ler PDF: $e')));
      }
    }
  }

  void _parseNewRecipes(String text) {
    // Exemplo de lógica para extrair blocos de receitas novos do PDF
    // Procura por padrão: TÍTULO DA RECEITA (em maiúsculo) seguido de "Ingredientes" e "Modo de preparo"
    final regExp = RegExp(r'([A-Z\s]+)\nIngredientes\n([\s\S]+?)\nModo de [pP]reparo\n([\s\S]+?)(?=\n[A-Z\s]+\n|$)');
    final matches = regExp.allMatches(text);

    setState(() {
      for (final match in matches) {
        String title = match.group(1)!.trim();
        String ingredients = match.group(2)!.trim();
        String method = match.group(3)!.trim();

        // Adiciona se não existir
        if (!_recipes.any((r) => r['title'] == title)) {
          _recipes.insert(0, {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'title': title,
            'ingredients': ingredients,
            'method': method,
            'category': text.contains('DOCE') ? 'Doce' : 'Salgado'
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = _recipes.where((r) => 
      r['title']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      r['category']!.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    const Color primaryOrange = Color(0xFFF57C00);
    const Color bgSoft = Color(0xFFFFF3E0);

    return Scaffold(
      backgroundColor: bgSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            backgroundColor: primaryOrange,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _importPDF, tooltip: 'Importar novas receitas'),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('Livro de Receitas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryOrange, Color(0xFFFFB74D)]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Buscar receita ou categoria...",
                  prefixIcon: const Icon(Icons.search, color: primaryOrange),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
          if (_isLoading) 
            const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildModernRecipeCard(filteredRecipes[index], primaryOrange),
                childCount: filteredRecipes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRecipeCard(Map<String, dynamic> recipe, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          backgroundColor: Colors.white, collapsedBackgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(recipe['category'] == 'Doce' ? Icons.icecream_outlined : Icons.restaurant, color: themeColor, size: 20),
          ),
          title: Text(recipe['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          subtitle: Text(recipe['category']!, style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.all(16),
          expandedAlignment: Alignment.topLeft,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildSectionHeader('INGREDIENTES', Icons.shopping_basket_outlined, themeColor),
              IconButton(icon: const Icon(Icons.edit_note, size: 20), onPressed: () => _showEditRecipeDialog(recipe))
            ]),
            const SizedBox(height: 8),
            Text(recipe['ingredients']!, style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black54)),
            const SizedBox(height: 20),
            _buildSectionHeader('MODO DE PREPARO', Icons.menu_book_outlined, themeColor),
            const SizedBox(height: 8),
            Text(recipe['method']!, style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  void _showEditRecipeDialog(Map<String, dynamic> recipe) {
    final titleController = TextEditingController(text: recipe['title']);
    final ingredientsController = TextEditingController(text: recipe['ingredients']);
    final methodController = TextEditingController(text: recipe['method']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Receita'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: ingredientsController, maxLines: 5, decoration: const InputDecoration(labelText: 'Ingredientes')),
            TextField(controller: methodController, maxLines: 5, decoration: const InputDecoration(labelText: 'Modo de Preparo')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                recipe['title'] = titleController.text;
                recipe['ingredients'] = ingredientsController.text;
                recipe['method'] = methodController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, letterSpacing: 1.2))]);
  }
}
