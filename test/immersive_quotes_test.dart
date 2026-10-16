import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/imagine/imagined_music.dart';
import 'package:waxclub/ui/widgets/immersive_quotes.dart';

void main() {
  testWidgets('imersivo no celular: a frase aparece quando a linha dela é cantada e some na próxima linha', (tester) async {
    var line = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ImmersiveQuotes(
          quotes: const [ImagineQuote(2, 'sung at line two'), ImagineQuote(3, 'too close'), ImagineQuote(9, 'later')],
          activeLine: () => line,
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('sung at line two'), findsNothing, reason: 'ainda não foi cantada');

    line = 2;
    await tester.pump(ImmersiveQuotes.tick);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('sung at line two'), findsOneWidget, reason: 'aparece na hora em que é cantada');
    AnimatedOpacity op() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(op().opacity, 1.0);

    line = 3; // próxima linha: some (depois do mínimo na tela); a frase da linha 3 está perto demais e não aparece
    await tester.pump(ImmersiveQuotes.minShown);
    await tester.pump(const Duration(milliseconds: 800));
    expect(op().opacity, 0.0);
    expect(find.text('too close'), findsNothing, reason: 'pelo menos ~10 s entre uma frase e outra');

    line = 9;
    await tester.pump(ImmersiveQuotes.gap);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('later'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
