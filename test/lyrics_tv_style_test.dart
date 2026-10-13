import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/lyric_line.dart';
import 'package:waxclub/ui/widgets/lyrics_list_view.dart';

void main() {
  test('caixa alta só para texto em alfabeto latino (acentos e pontuação incluídos), como na TV', () {
    expect(LyricsListView.isLatinText('Coming around again'), isTrue);
    expect(LyricsListView.isLatinText('Ilusão à toa, coração!'), isTrue);
    expect(LyricsListView.isLatinText('Ça va, señor? 1, 2, 3...'), isTrue);
    expect(LyricsListView.isLatinText('君の名は'), isFalse);
    expect(LyricsListView.isLatinText('Любовь'), isFalse);
    expect(LyricsListView.isLatinText('123 ...'), isFalse, reason: 'sem letras latinas não há o que pôr em caixa alta');
  });

  test('tamanhos e cores por distância da linha atual iguais aos da TV', () {
    expect(LyricsListView.scaleFor(0), 1.0);
    expect(LyricsListView.scaleFor(1), 1.0, reason: 'anterior e próxima no mesmo tamanho da atual');
    expect(LyricsListView.scaleFor(2), 0.76);
    expect(LyricsListView.scaleFor(5), 0.62);
    expect(LyricsListView.opacityFor(0), 1.0);
    expect(LyricsListView.opacityFor(1), 0.92);
    expect(LyricsListView.opacityFor(2), 0.24);
    expect(LyricsListView.opacityFor(4), 0.16);
  });

  testWidgets('letra aparece centralizada, em caixa alta e com a fonte Inter', (tester) async {
    // ignore: prefer_const_constructors
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LyricsListView(
          lyrics: [
            LyricLine(timestamp: Duration(seconds: 1), text: 'Baby sneezes'),
            LyricLine(timestamp: Duration(seconds: 4), text: 'Mommy pleases'),
            LyricLine(timestamp: Duration(seconds: 7), text: ''),
            LyricLine(timestamp: Duration(seconds: 9), text: 'Coming around again'),
          ],
          activeIndex: 1,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final current = tester.widget<Text>(find.text('MOMMY PLEASES').first);
    expect(current.textAlign, TextAlign.center);
    expect(find.text('BABY SNEEZES'), findsWidgets);
    expect(find.text('♪'), findsWidgets, reason: 'linha vazia vira a nota musical, como na TV');

    final style = tester.widget<AnimatedDefaultTextStyle>(
      find.ancestor(of: find.text('MOMMY PLEASES').first, matching: find.byType(AnimatedDefaultTextStyle)).first,
    );
    expect(style.style.fontFamily, 'Inter');
    expect(style.style.fontWeight, FontWeight.w800);
  });
}
