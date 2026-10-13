import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/ui/widgets/wood_tile_button.dart';

void main() {
  test('nome do botão entra e sai da esquerda para a direita', () {
    expect(IntroWipeLabel.visibleRange(0), (0.0, 0.0));
    final (s1, e1) = IntroWipeLabel.visibleRange(0.11);
    expect(s1, 0.0);
    expect(e1, inExclusiveRange(0.0, 1.0), reason: 'revelando: a borda direita avança');
    expect(IntroWipeLabel.visibleRange(0.5), (0.0, 1.0), reason: 'inteiro no meio');
    final (s2, e2) = IntroWipeLabel.visibleRange(0.9);
    expect(e2, 1.0);
    expect(s2, inExclusiveRange(0.0, 1.0), reason: 'sumindo: a borda esquerda avança para a direita');
    expect(IntroWipeLabel.visibleRange(1.0).$1, 1.0);
  });

  testWidgets('na abertura, o nome aparece embaixo do botão (fora da barra) e depois some', (tester) async {
    final key = GlobalKey();
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Stack(
        children: [
          Scaffold(
            appBar: AppBar(actions: [
              WoodTileButton(
                key: key,
                asset: 'assets/images/btn_collection.png',
                label: 'My Collection',
                onPressed: () => tapped = true,
              ),
            ]),
          ),
          Positioned.fill(
            child: IntroLabelsLayer(specs: [
              IntroLabelSpec(anchor: key, text: 'My Collection', delay: const Duration(milliseconds: 100)),
            ]),
          ),
        ],
      ),
    ));
    expect(find.text('My Collection'), findsNothing, reason: 'antes do atraso não aparece');

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1300)); // espera inicial da sequência
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('My Collection'), findsOneWidget);
    final label = tester.getRect(find.text('My Collection'));
    final button = tester.getRect(find.byType(Image));
    expect(label.top, greaterThan(button.bottom), reason: 'embaixo do botão');
    expect((label.center.dx - button.center.dx).abs(), lessThan(2), reason: 'centralizado no botão');

    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('My Collection'), findsNothing, reason: 'some no fim');

    await tester.tap(find.byType(Image));
    expect(tapped, isTrue);
  });

  testWidgets('nome com above: true aparece acima do botão', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Stack(
        children: [
          Scaffold(
            body: Center(
              child: WoodTileButton(key: key, asset: 'assets/images/btn_camera.png', label: 'Camera', onPressed: () {}),
            ),
          ),
          Positioned.fill(
            child: IntroLabelsLayer(specs: [
              IntroLabelSpec(anchor: key, text: 'Camera', delay: const Duration(milliseconds: 50), above: true),
            ]),
          ),
        ],
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 900));
    final label = tester.getRect(find.text('Camera'));
    final button = tester.getRect(find.byType(Image));
    expect(label.bottom, lessThan(button.top), reason: 'acima do botão');
    expect((label.center.dx - button.center.dx).abs(), lessThan(2));
    await tester.pump(const Duration(seconds: 2));
  });
}
