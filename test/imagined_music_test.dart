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

  final List<String> emotionCalls = [];
  @override
  Future<List<ImaginePhoto>> searchEmotion(String emotion) async {
    emotionCalls.add(emotion);
    if (fail) throw Exception('offline');
    return [
      for (var i = 1; i <= 3; i++)
        ImaginePhoto(id: '$emotion-$i', url: 'https://waxclub.com.br/imagined/art/$emotion-$i.webp', author: 'Artist', source: 'The Met', title: 'Feeling'),
    ];
  }

  @override
  Future<void> used(ImaginePhoto photo) async {}
}

String _fourScenes(String emotion) => '{"scenes":['
    '{"line":0,"query":"road","art":"road painting","emotion":"$emotion"},'
    '{"line":1,"query":"sea","art":"sea painting","emotion":"$emotion"},'
    '{"line":2,"query":"sky","art":"sky painting","emotion":"$emotion"},'
    '{"line":3,"query":"sky","art":"sky painting","emotion":"$emotion"}]}';

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

  test('sentimento da cena: só os da lista (o resto fica vazio)', () {
    final sb = Storyboard.parse(
        '{"scenes":[{"line":0,"query":"a","emotion":"Longing"},{"line":1,"query":"b","emotion":"boredom"}]}',
        lineCount: 3)!;
    expect(sb.scenes.map((s) => s.emotion), ['longing', '']);
  });

  test('a foto da letra manda; obra e sentimento 1 cena em 4 cada; sentimento não repete entre músicas', () async {
    final search = _FakeSearch();
    final im = ImaginedMusic(ai: await _ai(_fourScenes('sadness')), searcher: search, store: MemoryTranslatorStore());
    final a = (await im.storyboard(title: 'One', artist: 'Band', lines: ['x', 'y', 'z', 'q']))!;
    expect(a.scenes.map((s) => s.photo!.id), ['p1', 'art-sea painting', 'p-sky', 'sadness-1']);
    expect(search.queries, ['road', 'sea', 'sky'], reason: 'a mesma busca ("sky") é feita uma vez só na música');
    final b = (await im.storyboard(title: 'Two', artist: 'Band', lines: ['u', 'v', 'w', 'k']))!;
    expect(b.scenes[3].photo!.id, 'sadness-2', reason: 'a da música anterior fica de lado');
    expect(search.emotionCalls, ['sadness'], reason: 'a lista de cada sentimento vem uma vez');
  });

  test('tomadas: cada cena vira pedaços de ~13 s, uma foto por pedaço, até as fotos que ela tem', () {
    ImaginePhoto p(String id) => ImaginePhoto(id: id, url: 'https://x/$id', author: 'A');
    final sb = Storyboard(scenes: [
      ImagineScene(line: 0, query: 'a', photo: p('a1'), more: [p('a2'), p('a3')]),
      ImagineScene(line: 1, query: 'b', photo: p('b1')),
      const ImagineScene(line: 2, query: 'c'), // sem foto: não entra
    ]);
    final shots = sb.shots((s) => s.line * 40000, endMs: 60000);
    expect(shots.map((s) => s.photo.id), ['a1', 'a2', 'a3', 'b1']);
    expect(shots.map((s) => s.ms), [0, 13333, 26667, 40000]);
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
    // 1ª cena: foto da letra (com as outras fotos da mesma busca para as tomadas); 2ª: obra do acervo
    expect(sb.scenes.map((s) => s.photo!.id), ['p1', 'art-crowded city night rain']);
    expect(sb.scenes.first.more.map((p) => p.id), ['p-empty road at dawn']);
    expect(sb.scenes[1].photo!.credit, 'View — Painter · The Met');
    expect(search.queries, ['empty road at dawn', 'crowded city night rain']);
    expect(im.cached('Song', 'Band', lines), isNotNull);
    await im.storyboard(title: 'Song', artist: 'Band', lines: lines);
    expect(search.queries.length, 2, reason: 'a segunda vez vem do aparelho');
    expect(store.files['waxclub_storyboards_v2.json'], allOf(isNotNull, isNot(contains('l3'))), reason: 'a letra não é guardada');
  });

  test('busca de fotos falhou (sem chave do Unsplash / limite): não guarda, tenta de novo depois', () async {
    final search = _FakeSearch()..fail = true;
    final im = ImaginedMusic(ai: await _ai(_reply), searcher: search, store: MemoryTranslatorStore());
    final sb = await im.storyboard(title: 'Song', artist: 'Band', lines: ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(sb, isNotNull);
    expect(sb!.hasPhotos, isFalse);
    expect(im.cached('Song', 'Band', ['a', 'b', 'c', 'd', 'e', 'f']), isNull);
  });

  test('sem chip: avisa o motivo, avisa a tela só ao começar e ao terminar (sem laço) e não guarda', () async {
    final store = MemoryBrainKeyStore();
    final client = MockClient((_) async => _geminiReply('{}'));
    final brain = BrainService(store: store, client: client);
    await brain.load();
    final im = ImaginedMusic(ai: BrainAi(brain: brain, client: client), searcher: _FakeSearch(), store: MemoryTranslatorStore());
    var notes = 0;
    im.addListener(() => notes++);
    final sb = await im.storyboard(title: 'Song', artist: 'Band', lines: ['a', 'b']);
    await Future<void>.delayed(Duration.zero);
    expect(sb, isNull);
    expect(im.lastError, 'no_chip');
    expect(im.working, isFalse);
    expect(notes, lessThanOrEqualTo(3), reason: 'avisos contados, sem laço de novas tentativas');
  });

  test('resposta cortada ou fora do formato: motivo bad_reply', () async {
    final im = ImaginedMusic(ai: await _ai('{"scenes":[{"line":0,"query":"sea"'), searcher: _FakeSearch(), store: MemoryTranslatorStore());
    expect(await im.storyboard(title: 'Song', artist: 'Band', lines: ['a']), isNull);
    expect(im.lastError, 'bad_reply');
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
