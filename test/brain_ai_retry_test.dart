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

final _groq = 'gsk_${'b' * 40}';

http.Response _openAi(String text) => http.Response.bytes(
    utf8.encode(jsonEncode({
      'choices': [
        {
          'message': {'content': text}
        }
      ]
    })),
    200);

Future<BrainService> _brain(http.Client client, {bool two = false}) async {
  final store = MemoryBrainKeyStore()
    ..value = jsonEncode([
      {'id': 'gemini', 'key': _gemini, 'status': 'ok'},
      if (two) {'id': 'groq', 'key': _groq, 'status': 'ok'},
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

  test('dois chips: pedidos ao mesmo tempo (A2 e A3) vão para chips diferentes', () async {
    final hosts = <String>[];
    var running = 0;
    var maxRunning = 0;
    final client = MockClient((req) async {
      hosts.add(req.url.host);
      running++;
      maxRunning = running > maxRunning ? running : maxRunning;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      running--;
      return req.url.host.contains('groq') ? _openAi('from groq') : _ok('from gemini');
    });
    final ai = BrainAi(brain: await _brain(client, two: true), client: client, retryWait: Duration.zero);
    final out = await Future.wait([ai.complete(system: 's', user: 'a2'), ai.complete(system: 's', user: 'a3')]);
    expect(out.toSet(), {'from gemini', 'from groq'});
    expect(maxRunning, 2, reason: 'os dois chips trabalharam ao mesmo tempo');
  });

  test('chip sobrecarregado (503): o pedido passa para o próximo chip', () async {
    final client = MockClient((req) async =>
        req.url.host.contains('googleapis') ? http.Response('overloaded', 503) : _openAi('groq ok'));
    final ai = BrainAi(brain: await _brain(client, two: true), client: client, retryWait: const Duration(seconds: 30));
    expect(await ai.complete(system: 's', user: 'u'), 'groq ok');
  });

  test('modelo aposentado (404): o app consulta a lista do provedor, troca de modelo e tenta de novo', () async {
    final models = <String>[];
    final client = MockClient((req) async {
      if (req.url.host.contains('groq') && req.url.path.endsWith('/models')) {
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'data': [
                {'id': 'whisper-large-v3'},
                {'id': 'openai/gpt-oss-20b'},
                {'id': 'qwen/qwen3.8-27b'},
              ]
            })),
            200);
      }
      if (req.url.host.contains('groq')) {
        final model = (jsonDecode(req.body) as Map<String, dynamic>)['model'] as String;
        models.add(model);
        return model == 'openai/gpt-oss-20b' ? _openAi('new model ok') : http.Response('model not found', 404);
      }
      return http.Response('nope', 400); // gemini fora deste teste
    });
    final brain = await _brain(client, two: true);
    final ai = BrainAi(brain: brain, client: client, retryWait: Duration.zero);
    expect(await ai.complete(system: 's', user: 'u'), 'new model ok');
    expect(models, ['openai/gpt-oss-120b', 'openai/gpt-oss-20b']);
    expect(brain.plugged.firstWhere((p) => p.id == 'groq').model, 'openai/gpt-oss-20b', reason: 'o modelo novo fica guardado');
  });
}
