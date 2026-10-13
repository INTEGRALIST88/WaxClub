// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waxclub/main.dart';

void main() {
  testWidgets('WaxClub smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WaxClubApp());

    // Nome oficial exibido no título e na tela inicial vazia
    expect(find.text('WaxClub'), findsWidgets);
    expect(find.text('Vinyl Social Club'), findsWidgets);
    // Nomes antigos não podem aparecer
    for (final old in ['VyniLyric', 'VinyLyric', 'VinylSync']) {
      expect(find.textContaining(old), findsNothing);
    }
  });

  testWidgets('em pé: só o logo à esquerda (sem texto) e os botões de madeira cabem na barra', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WaxClubApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull, reason: 'nada pode estourar na barra superior');
    expect(find.text('Vinyl Social Club'), findsNothing, reason: 'o texto ao lado do logo só aparece deitado');
    for (final name in ['Camera', 'My Collection', 'Plugins', 'Help']) {
      expect(find.byTooltip(name), findsOneWidget, reason: 'botão $name');
    }
  });
}
