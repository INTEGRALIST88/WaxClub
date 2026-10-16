import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/imagine/imagined_music.dart';
import 'package:waxclub/ui/widgets/immersive_quotes.dart';

void main() {
  testWidgets('imersivo no celular: frase já cantada aparece, some e outra vem depois', (tester) async {
    var line = 5;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ImmersiveQuotes(
          quotes: const [ImagineQuote(1, 'first line'), ImagineQuote(4, 'sung already'), ImagineQuote(9, 'not yet')],
          activeLine: () => line,
        ),
      ),
    ));
    expect(find.text('sung already'), findsNothing, reason: 'nada nos primeiros segundos');
    await tester.pump(ImmersiveQuotes.firstAfter);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('sung already'), findsOneWidget, reason: 'a já cantada mais recente');
    line = 10;
    await tester.pump(ImmersiveQuotes.gap);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('not yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
