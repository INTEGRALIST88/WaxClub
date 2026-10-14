import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/dropbox/dropbox_service.dart';
import 'package:waxclub/services/local_lyrics_library.dart';

/// Pasta do app no Dropbox, em memória.
class _Folder implements LyricsFolderSource {
  final Map<String, ({String rev, String content})> files = {};
  int downloads = 0;

  @override
  Future<List<DropboxFile>> listAppFolder() async => [
        for (final e in files.entries)
          DropboxFile(path: e.key, name: e.key.split('/').last, rev: e.value.rev, size: e.value.content.length),
      ];

  @override
  Future<String> download(String path) async {
    downloads++;
    return files[path]!.content;
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_dropbox_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('PKCE: desafio S256 do RFC 7636 e cabeçalho com acentos escapados', () {
    expect(DropboxService.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    expect(DropboxService.headerJson({'path': '/Elis Regina - Águas de Março.lrc'}),
        '{"path":"/Elis Regina - \\u00c1guas de Mar\\u00e7o.lrc"}');
  });

  test('login: troca o código pelo acesso (com o mesmo state) e guarda; state diferente é recusado', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path == '/oauth2/token') {
        expect(req.bodyFields['client_id'], 'chave');
        expect(req.bodyFields['grant_type'], 'authorization_code');
        expect(req.bodyFields['code_verifier'], isNotEmpty);
        return http.Response(jsonEncode({'access_token': 'A1', 'refresh_token': 'R1', 'expires_in': 14400}), 200);
      }
      if (req.url.path == '/2/users/get_current_account') {
        return http.Response(jsonEncode({'name': {'display_name': 'Gustavo'}}), 200);
      }
      return http.Response('', 404);
    });
    final store = MemoryDropboxTokenStore();
    final d = DropboxService(store: store, client: client, appKey: 'chave');

    final url = d.authorizeUrl();
    expect(url.queryParameters['token_access_type'], 'offline');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    final state = url.queryParameters['state']!;
    expect(await d.finishLogin(Uri.parse('${DropboxConfig.redirectUri}?code=X&state=errado')), isFalse);

    d.authorizeUrl();
    final url2 = d.authorizeUrl();
    expect(url2.queryParameters['state'], isNot(state));
    expect(await d.finishLogin(Uri.parse('${DropboxConfig.redirectUri}?code=X&state=${url2.queryParameters['state']}')), isTrue);
    expect(d.isConnected, isTrue);
    expect(d.accountName, 'Gustavo');

    final again = DropboxService(store: store, client: client, appKey: 'chave');
    await again.load();
    expect(again.isConnected, isTrue, reason: 'fica salvo no aparelho');
  });

  test('acesso vencido é renovado pelo refresh token antes de listar a pasta', () async {
    final store = MemoryDropboxTokenStore()
      ..values['waxclub_dropbox'] = jsonEncode({'refresh': 'R1', 'access': 'velho', 'expires': '2000-01-01T00:00:00Z'});
    String? usedToken;
    final client = MockClient((req) async {
      if (req.url.path == '/oauth2/token') {
        expect(req.bodyFields['grant_type'], 'refresh_token');
        return http.Response(jsonEncode({'access_token': 'novo', 'expires_in': 14400}), 200);
      }
      if (req.url.path == '/2/files/list_folder') {
        usedToken = req.headers['Authorization'];
        return http.Response(
            jsonEncode({
              'entries': [
                {'.tag': 'file', 'name': 'A - B.lrc', 'path_display': '/A - B.lrc', 'rev': '1', 'size': 10},
                {'.tag': 'folder', 'name': 'Pasta', 'path_display': '/Pasta'},
              ],
              'has_more': false,
            }),
            200);
      }
      return http.Response('', 404);
    });
    final d = DropboxService(store: store, client: client, appKey: 'chave');
    await d.load();
    final files = await d.listAppFolder();
    expect(usedToken, 'Bearer novo');
    expect(files.map((f) => f.name), ['A - B.lrc']);
  });

  test('sincroniza: novos entram, alterados (revisão) são baixados de novo, apagados saem; os do seletor ficam', () async {
    final lib = LocalLyricsLibrary(directory: dir);
    await lib.importFiles([(name: 'Elis Regina - Como Nossos Pais.lrc', content: '[00:01.00]Não quero lhe falar')]);
    final folder = _Folder()
      ..files['/The Beatles - Something.lrc'] = (rev: 'r1', content: '[00:01.00]Something')
      ..files['/Abbey Road/The Beatles - Because.lrc'] = (rev: 'r1', content: '[00:02.00]Because')
      ..files['/notas.docx'] = (rev: 'r1', content: 'x')
      ..files['/semtraco.lrc'] = (rev: 'r1', content: '[00:01.00]linha');

    var r = await lib.syncFrom(folder);
    expect(r.added, 2);
    expect(r.skipped, ['semtraco.lrc']);
    expect(lib.count, 3);
    expect(lib.dropboxCount, 2);

    // Sem mudanças: nada é baixado de novo (exceto o arquivo que não foi entendido)
    folder.downloads = 0;
    r = await lib.syncFrom(folder);
    expect(r.added + r.updated + r.removed, 0);
    expect(folder.downloads, 1);

    // Um arquivo mudou e outro foi apagado no Dropbox
    folder.files['/The Beatles - Something.lrc'] = (rev: 'r2', content: '[00:01.00]Something in the way');
    folder.files.remove('/Abbey Road/The Beatles - Because.lrc');
    r = await lib.syncFrom(folder);
    expect(r.updated, 1);
    expect(r.removed, 1);
    expect(lib.find('Something', 'The Beatles')!.lyrics, contains('in the way'));
    expect(lib.find('Because', 'The Beatles'), isNull);
    expect(lib.find('Como Nossos Pais', 'Elis Regina'), isNotNull, reason: 'escolhido no seletor: fica');

    final again = LocalLyricsLibrary(directory: dir);
    await again.load();
    expect(again.dropboxCount, 1);
  });
}
