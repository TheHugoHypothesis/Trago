import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trago/main.dart';
import 'package:trago/state/app_state.dart';

void main() {
  testWidgets('Renderiza a nova interface do usuário final, catálogo e telas do Design.png', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const TragoApp(),
      ),
    );
    await tester.pump();

    // Verifica elementos da tela inicial (Design.png - Tela 1)
    expect(find.text('TRAGO'), findsOneWidget);
    expect(find.text('A Nova Rota da Importação Global'), findsOneWidget);
    expect(find.text('Quero importar um produto'), findsOneWidget);
    expect(find.text('Sou viajante'), findsOneWidget);
    expect(find.text('Catálogo Global em Destaque'), findsOneWidget);

    // Verifica barra de navegação inferior (Início, Pedidos, +, Viagens, Perfil)
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Viagens'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    // Navega para "Viagens" (Design.png - Tela 2: Encontrar um viajante)
    await tester.tap(find.text('Viagens'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Encontrar um viajante'), findsOneWidget);
    expect(find.text('Buscar viajantes'), findsOneWidget);
    expect(find.text('Ana C.'), findsOneWidget);

    // Seleciona a viajante Ana C. -> navega para "Detalhes do pedido" (Design.png - Tela 3)
    await tester.tap(find.text('Ana C.'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Detalhes do pedido'), findsOneWidget);
    expect(find.text('Cálculo estimado de valores'), findsOneWidget);
    expect(find.text('Sem surpresas!'), findsOneWidget);
    expect(find.text('Avançar para o pagamento'), findsOneWidget);
  });
}
