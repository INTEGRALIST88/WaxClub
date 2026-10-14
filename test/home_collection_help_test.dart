import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/collection_service.dart';
import 'package:waxclub/services/user_profile_store.dart';
import 'package:waxclub/ui/screens/collection_screen.dart';
import 'package:waxclub/ui/screens/help_screen.dart';
import 'package:waxclub/ui/widgets/home_greeting.dart';

void main() {
  group('Saudação da tela principal', () {
    test('usa o nome e a hora do dia', () {
      final morning = Greeting.forName('Gustavo', DateTime(2026, 10, 12, 9), 0);
      expect('${morning.title} ${morning.subtitle}', contains('Gustavo'));
      // Todas as variações de título levam o nome; as de horário respeitam o período
      for (var seed = 0; seed < 20; seed++) {
        final g = Greeting.forName('Ana', DateTime(2026, 10, 12, 15), seed);
        expect(g.title, contains('Ana'));
        expect(g.title, isNot(contains('morning')));
        expect(g.title, isNot(contains('evening')));
      }
      final evening = List.generate(20, (s) => Greeting.forName('Ana', DateTime(2026, 10, 12, 21), s).title);
      expect(evening.any((t) => t == 'Good evening, Ana!'), isTrue);
    });

    test('sem nome, dá boas-vindas e pede como chamar o usuário', () {
      final g = Greeting.forName(null, DateTime(2026, 10, 12, 9), 1);
      expect(g.title, 'Welcome to WaxClub!');
    });

    testWidgets('mostra o botão para informar o nome quando ainda não há nome', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HomeGreeting(name: null, seed: 1, onEditName: () => tapped = true)),
      ));
      await tester.tap(find.text('What should we call you?'));
      expect(tapped, isTrue);
    });
  });

  group('Coleção e audições', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_collection_'));
    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('qualquer faixa conta o disco uma vez por sessão (nova sessão após 2 h)', () async {
      final c = CollectionService(directory: dir);
      await c.load();
      final t0 = DateTime(2026, 10, 12, 20, 0);
      expect(await c.recordTrackPlay(album: 'O Outro Internacional', artist: 'Trilha sonora', track: 'Coming Around Again', at: t0), isTrue);
      expect(await c.recordTrackPlay(album: 'O Outro Internacional', artist: 'Trilha sonora', track: "Don't Dream It's Over", at: t0.add(const Duration(minutes: 4))), isFalse);
      // lado B, 25 min depois: mesma sessão
      await c.recordTrackPlay(album: 'O Outro Internacional', artist: 'Trilha sonora', track: "Don't Get Me Wrong", at: t0.add(const Duration(minutes: 25)));
      var stats = c.statsFor('O Outro Internacional', 'Trilha sonora');
      expect(stats.playCount, 1);
      // no dia seguinte: nova audição
      await c.recordTrackPlay(album: 'O Outro Internacional', artist: 'Trilha sonora', track: 'Two People', at: t0.add(const Duration(days: 1)));
      stats = c.statsFor('o outro internacional', 'TRILHA SONORA');
      expect(stats.playCount, 2);
      expect(stats.firstPlayedAt, t0);
      expect(c.historyFor('O Outro Internacional', 'Trilha sonora').first.track, 'Two People');
    });

    test('coleção e contagens são salvas no aparelho e recarregadas', () async {
      final c = CollectionService(directory: dir);
      await c.load();
      await c.add(CollectionItem(album: 'Pennybridge Pioneers', artist: 'Millencolin', addedAt: DateTime(2026, 10, 1), rating: 5));
      await c.recordTrackPlay(album: 'Pennybridge Pioneers', artist: 'Millencolin', track: 'No Cigar', at: DateTime(2026, 10, 2));

      final reopened = CollectionService(directory: dir);
      await reopened.load();
      expect(reopened.contains('Pennybridge Pioneers', 'Millencolin'), isTrue);
      expect(reopened.itemFor('Pennybridge Pioneers', 'Millencolin')!.rating, 5);
      expect(reopened.statsFor('Pennybridge Pioneers', 'Millencolin').playCount, 1);

      await reopened.remove('Pennybridge Pioneers', 'Millencolin');
      expect(reopened.count, 0);
    });

    test('nome do usuário é salvo no aparelho', () async {
      final p = UserProfileStore(directory: dir);
      await p.load();
      expect(p.displayName, isNull);
      await p.setDisplayName('  Gustavo ');
      final again = UserProfileStore(directory: dir);
      await again.load();
      expect(again.displayName, 'Gustavo');
    });

    testWidgets('tela da coleção lista os discos com as audições e abre o detalhe', (tester) async {
      final c = CollectionService();
      await tester.runAsync(() async {
        await c.load();
        await c.add(CollectionItem(album: 'Dancin’ Days Internacional', artist: 'Trilha sonora', addedAt: DateTime(2026, 10, 1)));
        await c.recordTrackPlay(album: 'Dancin’ Days Internacional', artist: 'Trilha sonora', track: 'Dancin Days', at: DateTime.now());
      });
      await tester.pumpWidget(MaterialApp(home: CollectionScreen(collection: c, tracklistFor: (_, __) => const [])));
      await tester.pump();
      expect(find.text('My Collection'), findsOneWidget);
      expect(find.text('Dancin’ Days Internacional'), findsOneWidget);
      expect(find.textContaining('Played 1×'), findsOneWidget);

      await tester.tap(find.text('Dancin’ Days Internacional'));
      await tester.pumpAndSettle();
      expect(find.text('LISTENING HISTORY'), findsOneWidget);
      expect(find.text('Remove from collection'), findsOneWidget);

      // Remover pede confirmação: "Cancel" mantém o disco; "Remove" tira da coleção
      await tester.ensureVisible(find.text('Remove from collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from collection'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to remove this record from your collection?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.items().length, 1, reason: 'cancelar não remove');

      await tester.tap(find.text('Remove from collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(c.items(), isEmpty);
      expect(find.text('Your collection is empty'), findsOneWidget);
    });

    testWidgets('coleção vazia explica como adicionar discos', (tester) async {
      final c = CollectionService();
      await tester.pumpWidget(MaterialApp(home: CollectionScreen(collection: c, tracklistFor: (_, __) => const [])));
      await tester.pump();
      expect(find.text('Your collection is empty'), findsOneWidget);
    });
  });

  testWidgets('tela de ajuda mostra os tópicos do manual e abre um deles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Getting started'), findsOneWidget);
    expect(HelpScreen.topics.length, greaterThanOrEqualTo(8));
    await tester.tap(find.text('Getting started'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap the microphone button'), findsOneWidget);
  });
}
