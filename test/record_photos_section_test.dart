import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/account/account_service.dart';
import 'package:waxclub/ui/widgets/record_photos_section.dart';

void main() {
  testWidgets('7 fotos por disco: botões desativados no limite; o × apaga com confirmação', (tester) async {
    final ids = List<int>.generate(7, (i) => i + 1);
    final deleted = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'GET' && req.url.path == '/v1/photos') {
        return http.Response(jsonEncode({'photos': [for (final id in ids) {'id': id, 'width': 100, 'height': 100, 'size': 10}]}), 200);
      }
      if (req.method == 'DELETE') {
        deleted.add(req.url.path);
        return http.Response(jsonEncode({'deleted': 1}), 200);
      }
      return http.Response('{}', 404);
    });
    final store = MemoryAccountStore();
    await store.write('waxclub.account.token', 'T');
    final account = AccountService(baseUrl: 'https://api.test/v1', store: store, client: client);
    await tester.runAsync(() => account.load());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: RecordPhotosSection(account: account, itemKey: 'disco|banda'))),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('7 of 7 photos'), findsOneWidget);
    final take = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Take photo'));
    expect(take.onPressed, isNull, reason: 'no limite de 7 não tira mais');

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Delete this photo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete photo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(deleted, ['/v1/photos/1']);
    expect(find.text('6 of 7 photos'), findsOneWidget);
    final again = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Take photo'));
    expect(again.onPressed, isNotNull, reason: 'apagou uma: cabe mais uma');
  });
}
