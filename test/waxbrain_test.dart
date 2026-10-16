import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/brain/brain_chips.dart';
import 'package:waxclub/services/brain/brain_service.dart';

// Chaves falsas, só com o formato de cada provedor
final _gemini = 'AIza${'a' * 35}';
final _groq = 'gsk_${'b' * 40}';
final _openrouter = 'sk-or-v1-${'c' * 64}';
final _openai = 'sk-proj-${'d' * 48}';
final _anthropic = 'sk-ant-api03-${'e' * 40}';
final _xai = 'xai-${'f' * 40}';
final _mistral = 'g' * 32;

class _FakeRemote implements BrainRemote {
  final Map<String, String> keys = {};
  bool configured = true;
  final List<String> calls = [];

  @override
  bool get available => true;

  @override
  Future<List<({String id, String hint})>?> list() async =>
      configured ? [for (final e in keys.entries) (id: e.key, hint: BrainChip.hintOf(e.value))] : null;

  @override
  Future<String?> key(String id) async => keys[id];

  @override
  Future<void> put(String id, String key, int position, BrainKeyStatus status) async {
    calls.add('put:$id');
    keys[id] = key;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    keys.remove(id);
  }

  @override
  Future<void> order(List<String> ids) async => calls.add('order:${ids.join(',')}');
}

BrainService _service(int Function(http.Request) status, {BrainKeyStore? store}) => BrainService(
      store: store ?? MemoryBrainKeyStore(),
      client: MockClient((req) async => http.Response(jsonEncode({'data': []}), status(req))),
    );

void main() {
  test('todos os 7 chips existem, grátis primeiro, nenhum encaixado de fábrica', () async {
    expect(BrainChip.all.map((c) => c.id),
        ['gemini', 'groq', 'openrouter', 'mistral', 'cerebras', 'github', 'openai', 'anthropic', 'xai', 'deepseek']);
    expect(BrainChip.all.where((c) => c.free).map((c) => c.id), ['gemini', 'groq', 'openrouter', 'mistral', 'cerebras', 'github']);
    expect(BrainChip.detect('csk-${'a1' * 16}')!.chip.id, 'cerebras');
    expect(BrainChip.detect('github_pat_${'A1b_' * 10}')!.chip.id, 'github');
    final brain = _service((_) => 200);
    await brain.load();
    expect(brain.plugged, isEmpty);
    expect(brain.hasChip, isFalse);
  });

  group('chave copiada reconhecida pelo formato', () {
    test('cada provedor de formato próprio é reconhecido sozinho', () {
      expect(BrainChip.detect(_gemini)!.chip.id, 'gemini');
      expect(BrainChip.detect('sk-${'0123456789abcdef' * 2}')!.chip.id, 'deepseek', reason: 'sk- + 32 hexadecimais é DeepSeek');
      expect(BrainChip.detect('sk-proj-${'Ab9_' * 12}')!.chip.id, 'openai');
      expect(BrainChip.detect(_groq)!.chip.id, 'groq');
      expect(BrainChip.detect(_openrouter)!.chip.id, 'openrouter');
      expect(BrainChip.detect(_openai)!.chip.id, 'openai');
      expect(BrainChip.detect(_anthropic)!.chip.id, 'anthropic');
      expect(BrainChip.detect(_xai)!.chip.id, 'xai');
    });

    test('chave da Anthropic e da OpenRouter não são confundidas com OpenAI', () {
      expect(BrainChip.byId('openai')!.matches(_anthropic), isFalse);
      expect(BrainChip.byId('openai')!.matches(_openrouter), isFalse);
    });

    test('Mistral (formato genérico) só com o chip escolhido', () {
      expect(BrainChip.detect(_mistral), isNull);
      expect(BrainChip.detect(_mistral, expected: BrainChip.byId('mistral'))!.chip.id, 'mistral');
    });

    test('texto comum, espaços e chave de outro formato não viram chave', () {
      expect(BrainChip.detect('hello world'), isNull);
      expect(BrainChip.detect('  $_gemini  ')!.key, _gemini, reason: 'espaços nas pontas são removidos');
      expect(BrainChip.detect(_groq, expected: BrainChip.byId('gemini')), isNull);
    });

    test('final da chave para exibir sem expô-la', () {
      expect(BrainChip.hintOf('abcdef1234'), '1234');
    });
  });

  test('resposta do teste da chave vira a situação do chip', () {
    expect(BrainService.statusForHttp(200), BrainKeyStatus.ok);
    expect(BrainService.statusForHttp(401), BrainKeyStatus.invalid);
    expect(BrainService.statusForHttp(403), BrainKeyStatus.invalid);
    expect(BrainService.statusForHttp(400), BrainKeyStatus.invalid, reason: 'Gemini responde 400 para chave inválida');
    expect(BrainService.statusForHttp(429), BrainKeyStatus.limit);
    expect(BrainService.statusForHttp(503), BrainKeyStatus.offline);
  });

  test('encaixar testa a chave no provedor certo; chave recusada não é encaixada', () async {
    final asked = <Uri>[];
    final brain = BrainService(
      store: MemoryBrainKeyStore(),
      client: MockClient((req) async {
        asked.add(req.url);
        return http.Response('{}', req.url.host.contains('groq') ? 401 : 200);
      }),
    );
    await brain.load();
    expect(await brain.plug(BrainChip.byId('gemini')!, _gemini), BrainKeyStatus.ok);
    expect(asked.last.host, 'generativelanguage.googleapis.com');
    expect(await brain.plug(BrainChip.byId('groq')!, _groq), BrainKeyStatus.invalid);
    expect(brain.plugged.map((p) => p.id), ['gemini']);
    expect(brain.activeChip!.id, 'gemini');
  });

  test('chave da Anthropic é testada com x-api-key (não Bearer)', () async {
    Map<String, String>? headers;
    final brain = BrainService(
      store: MemoryBrainKeyStore(),
      client: MockClient((req) async {
        headers = req.headers;
        return http.Response('{}', 200);
      }),
    );
    await brain.plug(BrainChip.byId('anthropic')!, _anthropic);
    expect(headers!['x-api-key'], _anthropic);
    expect(headers!.containsKey('Authorization'), isFalse);
  });

  test('chips ficam guardados no cofre, na ordem; desencaixar e reordenar persistem', () async {
    final store = MemoryBrainKeyStore();
    final brain = _service((_) => 200, store: store);
    await brain.plug(BrainChip.byId('gemini')!, _gemini);
    await brain.plug(BrainChip.byId('groq')!, _groq);
    await brain.plug(BrainChip.byId('xai')!, _xai);
    await brain.reorder(2, 0);
    await brain.unplug('groq');

    final reopened = _service((_) => 200, store: store);
    await reopened.load();
    expect(reopened.plugged.map((p) => p.id), ['xai', 'gemini']);
    expect(reopened.plugged.first.key, _xai);
  });

  test('chip no limite é pulado: o próximo pronto assume', () async {
    final brain = BrainService(
      store: MemoryBrainKeyStore(),
      client: MockClient((req) async => http.Response('{}', req.url.host.contains('googleapis') ? 429 : 200)),
    );
    await brain.plug(BrainChip.byId('gemini')!, _gemini);
    await brain.plug(BrainChip.byId('groq')!, _groq);
    expect(brain.plugged.first.status, BrainKeyStatus.limit, reason: 'encaixa mesmo no limite: volta a valer depois');
    expect(brain.activeChip!.id, 'groq');
  });

  group('cópia na conta', () {
    test('chips da conta descem para um celular novo; os do celular sobem', () async {
      final remote = _FakeRemote()..keys['openrouter'] = _openrouter;
      final brain = _service((_) => 200);
      await brain.plug(BrainChip.byId('gemini')!, _gemini); // antes de entrar na conta: só no celular
      await brain.attachRemote(remote);
      expect(brain.plugged.map((p) => p.id), containsAll(['gemini', 'openrouter']));
      expect(remote.keys['gemini'], _gemini, reason: 'chip só do celular sobe para a conta');
    });

    test('encaixar e desencaixar com a conta ligada atualizam a conta', () async {
      final remote = _FakeRemote();
      final brain = _service((_) => 200);
      await brain.attachRemote(remote);
      await brain.plug(BrainChip.byId('groq')!, _groq);
      await brain.unplug('groq');
      await Future<void>.delayed(Duration.zero);
      expect(remote.calls, ['put:groq', 'delete:groq']);
      expect(remote.keys, isEmpty);
    });

    test('servidor sem a senha do WaxBrain: segue só no celular, sem erro', () async {
      final remote = _FakeRemote()..configured = false;
      final brain = _service((_) => 200);
      await brain.plug(BrainChip.byId('gemini')!, _gemini);
      await brain.attachRemote(remote);
      expect(brain.plugged.map((p) => p.id), ['gemini']);
    });
  });
}
