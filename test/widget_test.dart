
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:citas_medicas_app/main.dart';

void main() {
  testWidgets(
    'La pantalla de autenticación se muestra correctamente',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Citas Médicas'), findsOneWidget);
      expect(find.text('Bienvenido'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
    },
  );
}
