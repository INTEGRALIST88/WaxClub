import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/brain/brain_ai.dart';
import 'package:waxclub/services/brain/brain_service.dart';

final _gemini = 'AIza${'a' * 35}';

http.Response _ok(String text) => http.Response.bytes(
    utf8.encode(jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    })),
    200);

Future<BrainService> _brain(http.Client client) async {
  final store = MemoryBrainKeyStore()
    ..value = jsonEncode([
      {'id': 'gemini', 'key': _gemini, 'status': 'ok'}
    ]);
  final b = BrainService(store: store, client: client);
  await b.load();
  return b;
}

void main() {
  test('429 (muitos pedidos por minuto): espera e tenta de novo o mesmo chip', () async {
    var calls = 0;
    final client = MockClient((_) async => ++calls == 1 ? http.Response('busy', 429) : _ok('fine'));
    final ai = BrainAi(brain: await _brain(client), client: client, retryWait: Duration.zero);
    expect(await ai.complete(system: 's', user: 'u'), 'fine');
    expect(calls, 2);
  });

  test('400 num pedido não desliga a chave', () async {
    final client = MockClient((_) async => http.Response('bad request', 400));
    final brain = await _brain(client);
    final ai = BrainAi(brain: brain, client: client, retryWait: Duration.zero);
    await expectLater(ai.complete(system: 's', user: 'u'), throwsA(isA<BrainAiException>()));
    expect(brain.activeChip?.id, 'gemini', reason: 'o chip continua pronto para o próximo pedido');
  });

  test('um pedido por vez (tradutor e Imagined Music dividem o chip)', () async {
    var running = 0;
    var maxRunning = 0;
    final client = MockClient((_) async {
      running++;
      maxRunning = running > maxRunning ? running : maxRunning;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      running--;
      return _ok('x');
    });
    final ai = BrainAi(brain: await _brain(client), client: client, retryWait: Duration.zero);
    await Future.wait([for (var i = 0; i < 3; i++) ai.complete(system: 's', user: '$i')]);
    expect(maxRunning, 1);
  });
}
