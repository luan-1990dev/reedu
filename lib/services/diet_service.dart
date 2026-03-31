class DietService {
  static final Map<String, List<String>> mealOptions = {
    'Café da Manhã': [
      'Opção 1: 1 pão francês s/ miolo + 3 ovos mexidos + café + 1 porção de fruta (maçã, pêra, ameixa, goiaba, pêssego, mamão ou melão)',
      'Opção 2: 2 fatias pão integral + 3 ovos mexidos + café + 1 porção de fruta (maçã, pêra, ameixa, goiaba, pêssego, mamão ou melão)',
      'Opção 3: 1 pão francês s/ miolo + 70g frango desfiado + café + 1 porção de fruta (maçã, pêra, ameixa, goiaba, pêssego, mamão ou melão)',
      'Opção 4: 1 crepioca (30g goma + 3 ovos) + 15g requeijão light + café + 1 porção de fruta (maçã, pêra, ameixa, goiaba, pêssego, mamão ou melão)',
    ],
    'Lanche da Manhã': [
      'Opção 1: 30g de whey protein isolado + 200ml de água + 1 banana nanica',
      'Opção 2: 1 pote de iogurte natural integral (170g) + 1 banana nanica',
    ],
    'Almoço': [
      'Opção 1 (Arroz): Arroz (120g) + Feijão (90g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
      'Opção 2 (Macarrão): Macarrão Integral (120g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
      'Opção 3 (Batata): Batata Doce (120g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
      'Opção 4 (Mandioca): Mandioca (120g) + Carne Magra (140g) + Vegetais A e B + Sobremesa',
    ],
    'Lanche da Tarde 1': [
      'Opção 1: 1 porção de fruta (maçã, pêra ou goiaba)',
    ],
    'Lanche da Tarde 2': [
      'Opção 1: 1 pão francês s/ miolo + 1 ovo mexido + café',
      'Opção 2: 2 fatias pão integral + 1 ovo mexido + café',
      'Opção 3: 2 fatias pão integral + 15g requeijão light + café',
      'Opção 4: 1 pão francês s/ miolo + 30g patê frango/atum + café',
      'Opção 5: 2 fatias pão integral + 10g pasta amendoim + café',
    ],
    'Jantar': [
      'Opção 1 (Arroz): Arroz (100g) + Feijão (60g) + Proteína (140g) + Vegetais A e B + Sobremesa',
      'Opção 2 (Batata): Batata Doce (100g) + Proteína (140g) + Vegetais A e B + Sobremesa',
      'Opção 3 (Macarrão): Macarrão Integral (100g) + Proteína (140g) + Vegetais A e B + Sobremesa',
    ],
  };

  static String getMealKey(String mealName) {
    if (mealName.contains('Café')) return 'cafe';
    if (mealName.contains('Lanche da Manhã')) return 'lanche_m';
    if (mealName.contains('Almoço')) return 'almoco';
    if (mealName.contains('Lanche da Tarde 1')) return 'lanche_t1';
    if (mealName.contains('Lanche da Tarde 2')) return 'lanche_t2';
    if (mealName.contains('Jantar')) return 'jantar';
    return 'outra';
  }
}
