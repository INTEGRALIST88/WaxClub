import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/account/account_service.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/ui/screens/sync_screen.dart';

/// Conta Discogs falsa (no app é o DiscogsAuthService: sair apaga as credenciais e desliga o plugin).
class _FakeDiscogs extends ChangeNotifier {
  bool enabled = true;
  String? user = 'vinylfan';
  int connects = 0;

  late final PluginConnection connection = PluginConnection(
    listenable: this,
    isEnabled: () => enabled,
    setEnabled: (v) async {
      enabled = v;
      notifyListeners();
    },
    isConnected: () => user != null,
    accountName: () => user,
    connect: () async {
      connects++;
      user = 'vinylfan';
      enabled = true;
      notifyListeners();
      return true;
    },
    disconnect: () async {
      user = null;
      enabled = false;
      notifyListeners();
    },
  );
}

void main() {
  testWidgets('nuvem: desconectar o Discogs pede confirmação e depois dá para conectar de novo pelo login', (tester) async {
    final account = AccountService(
      baseUrl: 'https://api.test/v1',
      store: MemoryAccountStore(),
      client: MockClient((_) async => http.Response('{}', 404)),
    );
    final discogs = _FakeDiscogs();
    await tester.pumpWidget(MaterialApp(home: SyncScreen(account: account, discogs: discogs.connection)));
    await tester.pump();
    expect(find.textContaining('vinylfan'), findsOneWidget);

    await tester.ensureVisible(find.text('Disconnect Discogs account'));
    await tester.tap(find.text('Disconnect Discogs account'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Discogs?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(discogs.user, 'vinylfan', reason: 'cancelar mantém a conta');

    await tester.tap(find.text('Disconnect Discogs account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(discogs.user, isNull);
    expect(find.text('Disconnect Discogs account'), findsNothing);

    // Refazer: "Connect Discogs" aparece mesmo com o plugin desligado pelo "sair" e refaz o login
    await tester.ensureVisible(find.text('Connect Discogs'));
    await tester.tap(find.text('Connect Discogs'));
    await tester.pumpAndSettle();
    expect(discogs.connects, 1);
    expect(find.textContaining('vinylfan'), findsOneWidget);
  });
}
