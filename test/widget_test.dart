// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waxclub/main.dart';

import 'helpers/fake_account.dart';

/// Abre o app com a conta e espera a sessão salva ser lida (sem esperar animações infinitas).
Future<void> pumpApp(WidgetTester tester, {bool signedIn = true, bool profileComplete = true}) async {
  await tester.pumpWidget(WaxClubApp(account: fakeAccount(signedIn: signedIn, profileComplete: profileComplete)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Fecha o app no fim do teste (a tela principal solta a coleção e cancela a sincronização agendada).
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  testWidgets('sem conta: a primeira tela é o login (e-mail e senha, criar conta, esqueci a senha)', (tester) async {
    await pumpApp(tester, signedIn: false);
    expect(find.text('Welcome to WaxClub'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byTooltip('My Collection'), findsNothing, reason: 'o app só abre depois do login');
    await closeApp(tester);
  });

  testWidgets('conta sem nome de usuário/local (Google ou login antigo): pede para completar o perfil', (tester) async {
    await pumpApp(tester, profileComplete: false);
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.byTooltip('My Collection'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('WaxClub smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await pumpApp(tester);

    // Nome oficial exibido no título e na tela inicial vazia
    expect(find.text('WaxClub'), findsWidgets);
    expect(find.text('Vinyl Social Club'), findsWidgets);
    // Nomes antigos não podem aparecer
    for (final old in ['VyniLyric', 'VinyLyric', 'VinylSync']) {
      expect(find.textContaining(old), findsNothing);
    }
    await closeApp(tester);
  });

  testWidgets('em pé: só o logo à esquerda (sem texto) e os botões de madeira cabem na barra', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull, reason: 'nada pode estourar na barra superior');
    expect(find.text('Vinyl Social Club'), findsNothing, reason: 'o texto ao lado do logo só aparece deitado');
    for (final name in ['Identify', 'Manual', 'My Collection', 'Plugins', 'Help']) {
      expect(find.byTooltip(name), findsOneWidget, reason: 'botão $name');
    }
    await closeApp(tester);
  });
}
