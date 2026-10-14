import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/account/account_service.dart';
import 'package:waxclub/services/plugins/plugin_links.dart';
import 'package:waxclub/ui/screens/auth/auth_gate.dart';

void main() {
  testWidgets('plugin pedido pelo site sem conta: a tela de login avisa e o pedido fica guardado', (tester) async {
    final account = AccountService(
      baseUrl: 'https://api.test/v1',
      store: MemoryAccountStore(),
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    PluginLinks.instance.handle('waxclub://plugin/install?id=lyrics.netease');
    addTearDown(() => PluginLinks.instance.take());

    await tester.pumpWidget(MaterialApp(home: AuthGate(account: account, app: (_) => const Text('app'))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('app'), findsNothing, reason: 'sem conta, o app não abre');
    expect(find.text('Sign in or create your WaxClub account to install the plugin S2 · NetEase Cloud Music.'), findsOneWidget);
    expect(PluginLinks.instance.pending.value, 'lyrics.netease', reason: 'instala depois do login');
  });
}
