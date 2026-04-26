import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/app/app.dart';

void main() {
  testWidgets('Renderiza rota inicial de inicio', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: App()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ponto Certo'), findsOneWidget);
    expect(find.text('Login da Empresa'), findsOneWidget);
  });
}
