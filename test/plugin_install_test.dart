import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      final files = Directory('site/plugins').listSync().whereType<File>().where((f) => !f.path.endsWith('index.json'));
      expect(files.length, 4);
      final store = PluginStore();
      for (final f in files) {
        final m = PluginManifest.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
        final p = store.byId(m.id);
        expect(p, isNotNull, reason: m.id);
        expect(p!.category.letter, m.category);
        expect(p.number, m.number);
        expect(p.engine, m.engine);
        expect(f.path.endsWith('${m.id}.json'), isTrue);
      }
      final index = jsonDecode(File('site/plugins/index.json').readAsStringSync()) as Map<String, dynamic>;
      expect((index['plugins'] as List).length, 4);
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
      final store = PluginStore(directory: dir);
      final installer = PluginInstaller(store: store, client: _site());
      expect(store.isLyricsEngineOn('lrclib'), isTrue, reason: 'LRCLIB vem com o app');
      expect(store.isLyricsEngineOn('netease'), isFalse);

      expect(await installer.install('lyrics.netease'), PluginInstallResult.installed);
      final netease = store.byId('lyrics.netease')!;
      expect(store.isInstalled(netease), isTrue);
      expect(store.isActive(netease), isTrue, reason: 'instalado já entra no prato');
      expect(store.isLyricsEngineOn('netease'), isTrue);
      expect(store.installedVersion(netease), '1.0.0');
      expect(await installer.install('lyrics.netease'), PluginInstallResult.alreadyInstalled);
      expect(await installer.install('lyrics.lrclib'), PluginInstallResult.builtIn);

      // Fica salvo no aparelho
      final again = PluginStore(directory: dir);
      await again.load();
      expect(again.isLyricsEngineOn('netease'), isTrue);

      expect(await store.uninstall(netease), isTrue);
      expect(store.isLyricsEngineOn('netease'), isFalse);
    });

    test('plugin inexistente, sem internet, desconhecido pelo app ou com integração trocada', () async {
      final store = PluginStore(directory: dir);
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

    test('quem já tinha o app (até a 1.4.8) continua com todas as fontes; app novo só com LRCLIB', () async {
      // Arquivo de plugins da 1.4.8: as fontes de letras ainda não eram plugins
      File('${dir.path}/waxclub_plugins.json').writeAsStringSync(jsonEncode({
        'version': 2,
        'installed': [],
        'active': ['lang.en', 'display.lyrics', 'display.curiosities'],
        'seenBuiltIns': ['lang.en', 'display.lyrics', 'display.curiosities', 'connect.discogs'],
      }));
      final old = PluginStore(directory: dir);
      await old.load();
      for (final e in ['lrclib', 'netease', 'megalobiz', 'lyrics.ovh']) {
        expect(old.isLyricsEngineOn(e), isTrue, reason: e);
      }

      final fresh = await Directory.systemTemp.createTemp('waxclub_plugins_new_');
      final store = PluginStore(directory: fresh);
      await store.load();
      expect(store.isLyricsEngineOn('lrclib'), isTrue);
      expect(store.isLyricsEngineOn('netease'), isFalse);
      await fresh.delete(recursive: true);
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
