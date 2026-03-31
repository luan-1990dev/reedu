import 'package:flutter_test/flutter_test.dart';
import 'package:reedu/main.dart';

void main() {
  testWidgets('App basic load test', (WidgetTester tester) async {
    // Agora passamos o parâmetro obrigatório isFirebaseReady para o teste
    await tester.pumpWidget(const MyApp(isFirebaseReady: false));

    // Apenas verifica se o app inicializa sem erros
    expect(find.byType(MyApp), findsOneWidget);
  });
}
