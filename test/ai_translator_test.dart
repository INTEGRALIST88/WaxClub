import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/models/lyric_line.dart';
import 'package:waxclub/services/ai_translator.dart';
import 'package:waxclub/services/brain/brain_ai.dart';
import 'package:waxclub/services/brain/brain_chips.dart';
import 'package:waxclub/services/brain/brain_service.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/services/plugins/plugin_manifest.dart';

final _gemini = 'AIza${'a' * 35}';
final _groq = 'gsk_${'b' * 40}';

http.Response _geminiReply(String text) => http.Response.bytes(
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

http.Response _openAiReply(String text) => http.Response.bytes(
    utf8.encode(jsonEncode({
      'choices': [
        {
          'message': {'content': text}
        }
      ]
    })),
    200);

/// WaxBrain com chips já encaixados (o teste da chave responde 200).
Future<BrainService> _brainWith(List<(String, String)> chips, http.Client client) async {
  final store = MemoryBrainKeyStore()
    ..value = jsonEncode([
      for (final (id, key) in chips) {'id': id, 'key': key, 'status': 'ok'},
    ]);
  final brain = BrainService(store: store, client: client);
  await brain.load();
  return brain;
}

void main() {
  group('executor de IA (BrainAi)', () {
    test('sem chip encaixado: avisa no_chip', () async {
      final brain = BrainService(store: MemoryBrainKeyStore(), client: MockClient((_) async => http.Response('{}', 200)));
      final ai = BrainAi(brain: brain, client: MockClient((_) async => http.Response('{}', 200)));
      expect(() => ai.complete(system: 's', user: 'u'), throwsA(isA<BrainAiException>()));
    });

    test('Gemini: pedido com instruções do sistema (regras do app + plugin) e resposta lida', () async {
      Map<String, dynamic>? body;
      Uri? url;
      final client = MockClient((req) async {
        url = req.url;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _geminiReply('olá');
      });
      final ai = BrainAi(brain: await _brainWith([('gemini', _gemini)], client), client: client);
      expect(await ai.complete(system: 'Translate.', user: '["hello"]'), 'olá');
      expect(url!.path, contains(':generateContent'));
      final system = body!['systemInstruction']['parts'][0]['text'] as String;
      expect(system, startsWith(BrainAi.appRules), reason: 'a moldura de regras do app vem antes do pedido do plugin');
      expect(system, endsWith('Translate.'));
    });

    test('chip no limite (429): descansa e o pedido passa ao próximo (não é marcado por uma recusa só)', () async {
      final client = MockClient((req) async {
        if (req.url.host.contains('googleapis')) return http.Response('{}', 429);
        return _openAiReply('from groq');
      });
      final brain = await _brainWith([('gemini', _gemini), ('groq', _groq)], client);
      final ai = BrainAi(brain: brain, client: client);
      expect(await ai.complete(system: 's', user: 'u'), 'from groq');
      expect(brain.plugged.first.status, BrainKeyStatus.ok, reason: 'limite por minuto é passageiro');
    });

    test('resposta de cada formato de API', () {
      expect(BrainAi.extractText(BrainApi.anthropic, {
        'content': [
          {'type': 'text', 'text': 'oi'}
        ]
      }), 'oi');
      expect(BrainAi.extractText(BrainApi.openAiCompatible, {'choices': []}), isNull);
    });
  });

  group('tradutor (A2)', () {
    test('sem idioma escolhido não traduz', () async {
      final client = MockClient((_) async => _geminiReply('[]'));
      final tr = AiTranslator(ai: BrainAi(brain: await _brainWith([('gemini', _gemini)], client), client: client), store: MemoryTranslatorStore());
      expect(await tr.translateLyrics(['hello'], title: 't', artist: 'a'), isNull);
    });

    test('traduz a letra linha por linha, guarda no celular e não pede de novo', () async {
      var calls = 0;
      String? prompt;
      final client = MockClient((req) async {
        calls++;
        prompt = (jsonDecode(req.body) as Map<String, dynamic>)['systemInstruction']['parts'][0]['text'] as String;
        return _geminiReply('```json\n["Olá", "", "Adeus"]\n```');
      });
      final store = MemoryTranslatorStore();
      final tr = AiTranslator(ai: BrainAi(brain: await _brainWith([('gemini', _gemini)], client), client: client), store: store);
      await tr.setLanguage(TranslatorLanguage.byCode('pt-BR')!);
      final lines = ['Hello', 'my friend', 'Goodbye'];
      expect(await tr.translateLyrics(lines, title: 'Song', artist: 'Band'), ['Olá', '', 'Adeus']);
      expect(prompt, contains('Brazilian Portuguese'));
      expect(prompt, contains('FIRST line'), reason: 'a IA pode agrupar a frase sob a primeira linha');
      expect(await tr.translateLyrics(lines, title: 'Song', artist: 'Band'), ['Olá', '', 'Adeus']);
      expect(calls, 1, reason: 'a segunda vez vem do que ficou guardado');
      expect(tr.cached('lyrics', lines), isNotNull);
      expect(store.files.containsKey('waxclub_translations.json'), isTrue);
      expect(store.files['waxclub_translator.json'], contains('pt-BR'));
    });

    test('resposta com quantidade de linhas diferente é descartada (a sincronia não pode mudar)', () async {
      final client = MockClient((_) async => _geminiReply('["só uma"]'));
      final tr = AiTranslator(ai: BrainAi(brain: await _brainWith([('gemini', _gemini)], client), client: client), store: MemoryTranslatorStore());
      await tr.setLanguage(TranslatorLanguage.byCode('es')!);
      expect(await tr.translateLyrics(['a', 'b'], title: 't', artist: 'a'), isNull);
      expect(tr.lastError, 'bad_reply');
    });

    test('lê o JSON mesmo com texto em volta', () {
      expect(AiTranslator.parseArray('Sure! ["a","b"] hope it helps', 2), ['a', 'b']);
      expect(AiTranslator.parseArray('no array here', 1), isNull);
    });
  });

  test('linha da letra: tradução vazia ou igual à original não aparece', () {
    final l = LyricLine(timestamp: Duration.zero, text: 'Hello');
    expect(l.withTranslation('Olá').translation, 'Olá');
    expect(l.withTranslation('').translation, isNull, reason: 'linha agrupada com a anterior');
    expect(l.withTranslation('Hello').translation, isNull);
  });

  test('plugin A2 não vem no app: instala pelo manifesto do site e entra ligado', () async {
    final store = PluginStore();
    final a2 = store.byId(PluginCatalog.translatorId)!;
    expect(a2.code, 'A2');
    expect(store.isInstalled(a2), isFalse, reason: 'nada pré-instalado');
    final manifest = PluginManifest.fromJson(
        jsonDecode(File('site/plugins/ai.translate.json').readAsStringSync()) as Map<String, dynamic>);
    expect(manifest.id, PluginCatalog.translatorId);
    expect(await store.installFromManifest(manifest), isTrue);
    expect(store.isInstalled(a2), isTrue);
    expect(store.isActive(a2), isTrue);
  });
}
