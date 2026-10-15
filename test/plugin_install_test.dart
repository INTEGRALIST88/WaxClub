import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/local_lyrics_library.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/services/plugins/plugin_links.dart';
import 'package:waxclub/services/plugins/plugin_manifest.dart';

/// O site de verdade: serve os manifestos de site/plugins (os mesmos arquivos publicados).
MockClient _site({Map<String, String> extra = const {}}) => MockClient((req) async {
      final path = req.url.path;
      if (extra.containsKey(path)) return http.Response(extra[path]!, 200);
      final f = File('site$path');
      if (req.url.host == 'waxclub.com.br' && f.existsSync()) {
        return http.Response.bytes(f.readAsBytesSync(), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('not found', 404);
    });

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_plugins_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  group('links do site', () {
    test('botão Install (link de app) e link para compartilhar', () {
      expect(PluginLinks.pluginIdFrom('waxclub://plugin/install?id=lyrics.netease'), 'lyrics.netease');
      expect(PluginLinks.pluginIdFrom('https://waxclub.com.br/install/?plugin=lyrics.megalobiz'), 'lyrics.megalobiz');
      expect(PluginLinks.pluginIdFrom('https://www.waxclub.com.br/install/?plugin=lyrics.lyricsovh'), 'lyrics.lyricsovh');
    });

    test('links de outros sites ou ids estranhos são ignorados', () {
      expect(PluginLinks.pluginIdFrom('https://example.com/install/?plugin=lyrics.netease'), isNull);
      expect(PluginLinks.pluginIdFrom('waxclub://plugin/install?id=../etc'), isNull);
      expect(PluginLinks.pluginIdFrom('https://waxclub.com.br/?plugin=lyrics.netease'), isNull);
      expect(PluginLinks.pluginIdFrom(null), isNull);
    });
  });

  group('manifesto (só dados)', () {
    test('todo manifesto publicado no site bate com um plugin que o app conhece', () {
      final files = Directory('site/plugins').listSync().whereType<File>().where((f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'));
      expect(files.length, 5);
      final store = PluginStore(bundleLyricsSources: false);
      for (final f in files) {
        final m = PluginManifest.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
        final p = store.byId(m.id);
        expect(p, isNotNull, reason: m.id);
        expect(p!.category.letter, m.category);
        expect(p.number, m.number);
        expect(p.engine, m.engine);
        expect(f.path.endsWith('${m.id}.json'), isTrue);
        final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        expect(raw['builtIn'], isFalse, reason: 'o app da loja não traz fonte de letras: nenhuma é embutida no site');
        expect(p.isBuiltIn, isFalse);
      }
      final index = jsonDecode(File('site/plugins/index.json').readAsStringSync()) as Map<String, dynamic>;
      expect((index['plugins'] as List).length, 5);
    });

    test('formato errado, versão nova do formato e id inválido são recusados', () {
      Map<String, dynamic> base() => {
            'format': 'waxclub-plugin',
            'formatVersion': 1,
            'id': 'lyrics.netease',
            'category': 'S',
            'number': 2,
            'name': 'NetEase Cloud Music',
            'version': '1.0.0',
            'provides': {'engine': 'netease'},
          };
      expect(PluginManifest.fromJson(base()).engine, 'netease');
      expect(() => PluginManifest.fromJson(base()..['format'] = 'other'), throwsFormatException);
      expect(() => PluginManifest.fromJson(base()..['formatVersion'] = 2), throwsFormatException);
      expect(() => PluginManifest.fromJson(base()..['id'] = 'NetEase'), throwsFormatException);
      expect(() => PluginManifest.fromJson(base()..remove('version')), throwsFormatException);
    });
  });

  group('instalar pelo site', () {
    test('instala, liga a fonte de letras e não instala de novo; desinstalar desliga', () async {
      final store = PluginStore(directory: dir, bundleLyricsSources: false);
      final installer = PluginInstaller(store: store, client: _site());
      expect(store.isLyricsEngineOn('lrclib'), isFalse, reason: 'app da loja: nenhuma fonte de letras de fábrica');
      expect(store.isLyricsEngineOn('netease'), isFalse);
      expect(await installer.install('lyrics.lrclib'), PluginInstallResult.installed);
      expect(store.isLyricsEngineOn('lrclib'), isTrue);

      expect(await installer.install('lyrics.netease'), PluginInstallResult.installed);
      final netease = store.byId('lyrics.netease')!;
      expect(store.isInstalled(netease), isTrue);
      expect(store.isActive(netease), isTrue, reason: 'instalado já entra no prato');
      expect(store.isLyricsEngineOn('netease'), isTrue);
      expect(store.installedVersion(netease), '1.0.0');
      expect(await installer.install('lyrics.netease'), PluginInstallResult.alreadyInstalled);
      expect(await installer.install('lang.en'), PluginInstallResult.builtIn);

      // Fica salvo no aparelho
      final again = PluginStore(directory: dir, bundleLyricsSources: false);
      await again.load();
      expect(again.isLyricsEngineOn('netease'), isTrue);

      expect(await store.uninstall(netease), isTrue);
      expect(store.isLyricsEngineOn('netease'), isFalse);
    });

    test('plugin inexistente, sem internet, desconhecido pelo app ou com integração trocada', () async {
      final store = PluginStore(directory: dir, bundleLyricsSources: false);
      expect(await PluginInstaller(store: store, client: _site()).install('lyrics.nada'), PluginInstallResult.notFound);
      final offline = MockClient((_) async => throw const SocketException('offline'));
      expect(await PluginInstaller(store: store, client: offline).install('lyrics.netease'), PluginInstallResult.network);

      String manifest(String id, String engine) => jsonEncode({
            'format': 'waxclub-plugin',
            'formatVersion': 1,
            'id': id,
            'category': 'S',
            'number': 9,
            'name': 'Futuro',
            'version': '1.0.0',
            'provides': {'engine': engine},
          });
      final future = _site(extra: {'/plugins/lyrics.futuro.json': manifest('lyrics.futuro', 'futuro')});
      expect(await PluginInstaller(store: store, client: future).install('lyrics.futuro'), PluginInstallResult.needsUpdate);
      final swapped = _site(extra: {'/plugins/lyrics.megalobiz.json': manifest('lyrics.megalobiz', 'netease')});
      expect(await PluginInstaller(store: store, client: swapped).install('lyrics.megalobiz'), PluginInstallResult.invalid,
          reason: 'o manifesto não pode ligar outra integração');
      expect(store.isLyricsEngineOn('netease'), isFalse);
    });

    test('antes do lançamento: as 4 fontes da web vêm instaladas uma vez; depois vale a escolha do usuário', () async {
      // Arquivo de plugins da 1.4.8 (as fontes de letras ainda não eram plugins)
      File('${dir.path}/waxclub_plugins.json').writeAsStringSync(jsonEncode({
        'version': 2,
        'installed': [],
        'active': ['lang.en', 'display.lyrics', 'display.curiosities'],
        'seenBuiltIns': ['lang.en', 'display.lyrics', 'display.curiosities', 'connect.discogs'],
      }));
      final old = PluginStore(directory: dir, bundleLyricsSources: true);
      await old.load();
      for (final e in ['lrclib', 'netease', 'megalobiz', 'lyrics.ovh']) {
        expect(old.isLyricsEngineOn(e), isTrue, reason: e);
      }
      expect(old.isLyricsEngineOn('local'), isFalse, reason: 'S5 é instalado pelo usuário');

      // O usuário desinstala uma: não volta sozinha
      await old.uninstall(old.byId('lyrics.megalobiz')!);
      final again = PluginStore(directory: dir, bundleLyricsSources: true);
      await again.load();
      expect(again.isLyricsEngineOn('megalobiz'), isFalse);
      expect(again.isLyricsEngineOn('netease'), isTrue);

      // App da loja (depois do lançamento): nada de fábrica
      final fresh = await Directory.systemTemp.createTemp('waxclub_plugins_new_');
      final store = PluginStore(directory: fresh, bundleLyricsSources: false);
      await store.load();
      expect(store.isLyricsEngineOn('lrclib'), isFalse);
      await fresh.delete(recursive: true);
    });
  });

  group('S5 My lyrics files', () {
    test('lê as tags do .lrc ou o nome "Artista - Música"; recusa o que não entende', () {
      final tagged = LocalLyricsLibrary.parse(
          'qualquer.lrc', '[ar:The Beatles]\n[ti:Here Comes the Sun]\n[al:Abbey Road]\n[length:03:05]\n[00:00.80]Here comes the sun');
      expect(tagged!.artist, 'The Beatles');
      expect(tagged.title, 'Here Comes the Sun');
      expect(tagged.album, 'Abbey Road');
      expect(tagged.durationSeconds, 185);
      expect(tagged.lyrics, '[00:00.80]Here comes the sun');

      final named = LocalLyricsLibrary.parse('Os Mutantes - Panis et Circenses.lrc', '[00:01.00]Eu quis cantar');
      expect(named!.artist, 'Os Mutantes');
      expect(named.title, 'Panis et Circenses');
      expect(LocalLyricsLibrary.parse('Elis Regina - Como Nossos Pais.txt', 'Não quero lhe falar')!.title, 'Como Nossos Pais');

      expect(LocalLyricsLibrary.parse('semtraco.lrc', '[00:01.00]linha'), isNull, reason: 'sem artista/música');
      expect(LocalLyricsLibrary.parse('Banda - Música.pdf', 'x'), isNull, reason: 'só .lrc e .txt');
      expect(LocalLyricsLibrary.parse('Banda - Música.lrc', '[ar:Banda]\n[ti:Música]'), isNull, reason: 'sem letra');
    });

    test('importa, acha pela música (sem ligar para maiúsculas e "The") e vence as fontes da web', () async {
      final lib = LocalLyricsLibrary(directory: dir);
      final r = await lib.importFiles([
        (name: 'The Beatles - Something.lrc', content: '[00:01.00]Something in the way she moves\n[00:06.00]Attracts me like no other lover\n[00:12.00]Something in the way she woos me'),
        (name: 'foto.jpg', content: 'x'),
      ]);
      expect(r.added, 1);
      expect(r.skipped, ['foto.jpg']);
      expect(lib.find('something', 'Beatles'), isNotNull);

      // Fica salvo no aparelho
      final again = LocalLyricsLibrary(directory: dir);
      await again.load();
      expect(again.count, 1);

      final hosts = <String>[];
      final client = MockClient((req) async {
        hosts.add(req.url.host);
        return http.Response('[]', 404);
      });
      LyricsProviderService.myLyrics = again;
      LyricsProviderService.sourceEnabled = (s) => s == 'local' || s == 'lrclib';
      addTearDown(() {
        LyricsProviderService.myLyrics = null;
        LyricsProviderService.sourceEnabled = (_) => true;
      });
      final got = await LyricsProviderService(client: client).fetchLyricsDetails(trackName: 'Something', artistName: 'The Beatles');
      expect(got?.source, 'local');
      expect(got?.syncedLyrics, contains('Something in the way'));
      expect(hosts, isEmpty, reason: 'com a letra do usuário, nenhuma consulta à web');

      // Com o plugin S5 desligado, a letra do usuário não é usada
      LyricsProviderService.sourceEnabled = (s) => s == 'lrclib';
      final web = await LyricsProviderService(client: client).fetchLyricsDetails(trackName: 'Something', artistName: 'The Beatles');
      expect(web?.source, isNot('local'));
    });
  });

  test('a busca de letras só consulta as fontes ligadas', () async {
    final hosts = <String>[];
    final client = MockClient((req) async {
      hosts.add(req.url.host);
      return http.Response('[]', 404);
    });
    LyricsProviderService.sourceEnabled = (s) => s == 'lrclib';
    addTearDown(() => LyricsProviderService.sourceEnabled = (_) => true);
    await LyricsProviderService(client: client).fetchLyricsDetails(trackName: 'Song', artistName: 'Band');
    expect(hosts, isNotEmpty);
    expect(hosts.every((h) => h.contains('lrclib')), isTrue, reason: 'consultou: $hosts');
  });
}
