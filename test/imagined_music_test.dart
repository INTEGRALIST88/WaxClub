import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/ai_translator.dart';
import 'package:waxclub/services/brain/brain_ai.dart';
import 'package:waxclub/services/brain/brain_service.dart';
import 'package:waxclub/services/imagine/imagined_music.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/services/plugins/plugin_manifest.dart';

final _gemini = 'AIza${'a' * 35}';

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

Future<BrainAi> _ai(String reply) async {
  final client = MockClient((_) async => _geminiReply(reply));
  final store = MemoryBrainKeyStore()
    ..value = jsonEncode([
      {'id': 'gemini', 'key': _gemini, 'status': 'ok'}
    ]);
  final brain = BrainService(store: store, client: client);
  await brain.load();
  return BrainAi(brain: brain, client: client);
}

class _FakeSearch implements ImagineSearch {
  final List<String> queries = [];
  bool fail = false;
  @override
  Future<List<ImaginePhoto>> search(String query) async {
    queries.add(query);
    if (fail) throw Exception('rate limited');
    // as duas primeiras fotos são sempre as mesmas: a segunda cena não pode repetir a primeira
    return [
      const ImaginePhoto(id: 'p1', url: 'https://images.unsplash.com/photo-1', author: 'Ana'),
      ImaginePhoto(id: 'p-$query', url: 'https://images.unsplash.com/photo-$query', author: 'Bruno'),
    ];
  }

  @override
  Future<List<ImaginePhoto>> searchArt(String query) async {
    if (fail) throw Exception('offline');
    return [ImaginePhoto(id: 'art-$query', url: 'https://waxclub.com.br/imagined/art/$query.webp', author: 'Painter', source: 'The Met', title: 'View')];
  }

  @override
  Future<void> used(ImaginePhoto photo) async {}
}

const _reply = '''Here you go:
{"scenes":[
  {"line":0,"query":"empty road at dawn","mood":"hopeful","palette":["#1b2a49","#f2c14e","bad"],"motion":"zoom_in","transition":"dissolve","intensity":0.4},
  {"line":3,"query":"crowded city night rain","mood":"lonely","palette":["#0a1a2f"],"motion":"pan_left","transition":"cut","intensity":0.9},
  {"line":2,"query":"out of order scene","mood":"x"},
  {"line":99,"query":"beyond the lyrics"}
],
"quotes":[{"line":1,"text":"a line to remember"},{"line":50,"text":"no such line"}]}''';

void main() {
  test('roteiro: cenas em ordem e dentro da letra, cores válidas, frases só de linhas existentes', () {
    final sb = Storyboard.parse(_reply, lineCount: 6)!;
    expect(sb.scenes.map((s) => s.line), [0, 3], reason: 'fora de ordem e fora da letra são descartadas');
    expect(sb.scenes.first.palette, ['#1b2a49', '#f2c14e']);
    expect(sb.scenes[1].transition, 'cut');
    expect(sb.scenes[1].motion, 'pan_left');
    expect(sb.quotes.map((q) => q.text), ['a line to remember']);
    expect(Storyboard.parse('no json', lineCount: 3), isNull);
  });

  test('primeira cena sempre começa na linha 0', () {
    final sb = Storyboard.parse('{"scenes":[{"line":2,"query":"sea"}]}', lineCount: 5)!;
    expect(sb.scenes.single.line, 0);
  });

  test('uma foto por cena, sem repetir; roteiro guardado e não refeito', () async {
    final search = _FakeSearch();
    final store = MemoryTranslatorStore();
    final im = ImaginedMusic(ai: await _ai(_reply), searcher: search, store: store);
    final lines = ['l0', 'l1', 'l2', 'l3', 'l4', 'l5'];
    final sb = (await im.storyboard(title: 'Song', artist: 'Band', lines: lines))!;
    // cena par: foto do Unsplash; cena ímpar: obra do acervo
    expect(sb.scenes.map((s) => s.photo!.id), ['p1', 'art-crowded city night rain']);
    expect(sb.scenes[1].photo!.credit, 'View — Painter · The Met');
    expect(search.queries, ['empty road at dawn']);
    expect(im.cached('Song', 'Band', lines), isNotNull);
    await im.storyboard(title: 'Song', artist: 'Band', lines: lines);
    expect(search.queries.length, 1, reason: 'a segunda vez vem do aparelho');
    expect(store.files['waxclub_storyboards.json'], isNot(contains('l3')), reason: 'a letra não é guardada');
  });

  test('busca de fotos falhou (sem chave do Unsplash / limite): não guarda, tenta de novo depois', () async {
    final search = _FakeSearch()..fail = true;
    final im = ImaginedMusic(ai: await _ai(_reply), searcher: search, store: MemoryTranslatorStore());
    final sb = await im.storyboard(title: 'Song', artist: 'Band', lines: ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(sb, isNotNull);
    expect(sb!.hasPhotos, isFalse);
    expect(im.cached('Song', 'Band', ['a', 'b', 'c', 'd', 'e', 'f']), isNull);
  });

  test('modo imersivo fica guardado', () async {
    final store = MemoryTranslatorStore();
    final im = ImaginedMusic(ai: await _ai('{}'), store: store);
    await im.setMode(ImagineMode.immersive);
    final again = ImaginedMusic(ai: await _ai('{}'), store: store);
    await again.load();
    expect(again.mode, ImagineMode.immersive);
  });

  test('foto no tamanho do WaxClub (512 px)', () {
    const p = ImaginePhoto(id: 'x', url: 'https://images.unsplash.com/photo-x?ixid=1', author: 'A');
    expect(p.sized(), 'https://images.unsplash.com/photo-x?ixid=1&w=512&q=75&auto=format&fit=max');
  });

  test('A3 não vem no app: instala pelo manifesto do site', () async {
    final store = PluginStore();
    final a3 = store.byId(PluginCatalog.imaginedId)!;
    expect(a3.code, 'A3');
    expect(store.isInstalled(a3), isFalse);
    final m = PluginManifest.fromJson(jsonDecode(File('site/plugins/ai.imagined.json').readAsStringSync()) as Map<String, dynamic>);
    expect(await store.installFromManifest(m), isTrue);
    expect(store.isActive(a3), isTrue);
  });
}
